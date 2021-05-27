(ns ebf.core
  (:require [clojure.string :as str :refer [split]]))

(def ui-state {:browser-fonts  {:enable  {:pref  {:value false}
                                          :icon  {:path "icons/on.svg"}
                                          :title {:title "Using Browser Fonts"}}
                                :disable {:pref  {:value true}
                                          :icon  {:path "icons/off.svg"}
                                          :title {:title "Using Website Fonts"}}}
               :document-fonts {:enable  {:pref  {:value true}
                                          :icon  {:path "icons/off.svg"}
                                          :title {:title "Using Website Fonts"}}
                                :disable {:pref  {:value false}
                                          :icon  {:path "icons/on.svg"}
                                          :title {:title "Using Browser Fonts"}}}})

(def app-state (atom {:default-fonts   :browser-fonts
                      :browser-fonts   {:exclude #{}}
                      :document-fonts  {:exclude #{}}
                      :current-tab-url nil}))

(defn set-browser-pref! [{pref :pref}]
  (.set (.-useDocumentFonts (.-browserSettings js/browser)) (clj->js pref)))

(defn set-addon-icon! [{icon :icon}]
  (.setIcon (.-browserAction js/browser) (clj->js icon)))

(defn set-addon-title! [{title :title}]
  (.setTitle (.-browserAction js/browser) (clj->js title)))

(defn configure-addon-for-current-site! [config]
  (.all js/Promise [(set-browser-pref! config)
                    (set-addon-icon! config)
                    (set-addon-title! config)]))

(defn load-state-from-storage! []
  (-> (.get (.-local (.-storage js/browser)))
    (.then #(js->clj % :keywordize-keys true))
    (.then #(assoc % :default-fonts (keyword (:default-fonts % (clj->js (:default-fonts @app-state))))))
    (.then #(update-in % [:browser-fonts :exclude] set (:exclude (:browser-fonts %))))
    (.then #(update-in % [:document-fonts :exclude] set (:exclude (:document-fonts %))))
    (.then #(swap! app-state merge %))))

(defn write-to-storage! [key atom old-state new-state]
  (->> (select-keys new-state [:default-fonts :browser-fonts :document-fonts])
    (clj->js)
    (.set (.-local (.-storage js/browser)))))

(defn configure-addon-for-current-site [key atom old-state new-state]
  (let [current-domain (:current-tab-url new-state)
        font-type (:default-fonts new-state)
        excluded-domains (:exclude (font-type new-state))
        ui (font-type ui-state)]
    (if-not (nil? current-domain)
      (if (contains? excluded-domains current-domain)
        (configure-addon-for-current-site! (:disable ui))
        (configure-addon-for-current-site! (:enable ui))))))

(defn log [key atom old-state new-state]
  (println "old: " old-state)
  (println "new: " new-state))

(defn domain-name [url]
  (get (str/split url #"/") 2))

(defn tab-activated [active-info]
  (let [tabId (:tabId (js->clj active-info :keywordize-keys true))]
    (-> (.get (.-tabs js/browser) tabId)
      (.then #(js->clj % :keywordize-keys true))
      (.then #(:url %))
      (.then #(domain-name %))
      (.then #(swap! app-state assoc :current-tab-url %)))))

(defn tab-changed [tab-id change-info tab-info]
  (let [url (:url (js->clj change-info :keywordize-keys true))
        active (:active (js->clj tab-info :keywordize-keys true))]
    (if (and active (not (nil? url)))
      (swap! app-state assoc :current-tab-url (domain-name url)))))

(defn browser-action-activated []
  (let [current-url (:current-tab-url @app-state)
        default-fonts (:default-fonts @app-state)
        not-default-fonts (if (= default-fonts :browser-fonts) :document-fonts :browser-fonts)]
    (if (contains? (:exclude (default-fonts @app-state)) current-url)
      (swap! app-state update-in [default-fonts :exclude] disj current-url)
      (swap! app-state update-in [default-fonts :exclude] conj current-url))
    (swap! app-state update-in [not-default-fonts :exclude] disj current-url)))

(defn handle-communication-with-preference-page [request sender send-response]
  (let [req (js->clj request :keywordize-keys true)
        message (:message req)
        data (js->clj (:data req) :keywordize-keys)]
    (cond (= message "get-preferences") (send-response (clj->js @app-state))
      (= message "set-preferences") (swap! app-state assoc :default-fonts (keyword (:default-fonts data))))))

(defn start-watchers []
  ;(add-watch app-state :log log)
  (add-watch app-state :write-to-storage! write-to-storage!)
  (add-watch app-state :configure-addon-for-current-site configure-addon-for-current-site))

(defn start-event-listeners []
  (.addListener (.-onActivated (.-tabs js/browser)) tab-activated)
  (.addListener (.-onUpdated (.-tabs js/browser)) tab-changed)
  (.addListener (.-onClicked (.-browserAction js/browser)) browser-action-activated)
  (.addListener (.-onMessage (.-runtime js/browser)) handle-communication-with-preference-page))

(defn initialize-state []
  (load-state-from-storage!)
  (-> (.query (.-tabs js/browser) #js {:currentWindow true :active true})
    (.then #(js->clj % :keywordize-keys true))
    (.then first)
    (.then #(:url %))
    (.then domain-name)
    (.then #(swap! app-state assoc :current-tab-url %))))

(defn init []
  (start-watchers)
  (start-event-listeners)
  (initialize-state))

;(.addListener (.-onInstalled (.-runtime js/browser)) init)
;(.addListener (.-onStartup (.-runtime js/browser)) init)
(.addEventListener js/document "DOMContentLoaded" init)

