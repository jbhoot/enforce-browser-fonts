(ns ebf.core
  (:require [clojure.string :as str :refer [split]]))

(def addon-storage (.-local (.-storage js/browser)))

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
                      :browser-fonts   {:exclude '()}
                      :document-fonts  {:exclude '()}
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
  (-> (.get addon-storage)
      (.then #(js->clj % :keywordize-keys true))
      (.then #(assoc % :default-fonts (keyword (:default-fonts % (clj->js (:default-fonts @app-state))))))
      (.then #(swap! app-state merge %))))

(defn write-to-storage! [key atom old-state new-state]
  (->> (select-keys new-state [:default-fonts :browser-fonts :document-fonts])
       (clj->js)
       (.set addon-storage)))

(defn configure-addon-for-current-site [key atom old-state new-state]
  (let [current-domain (:current-tab-url new-state)
        font-type (:default-fonts new-state)
        excluded-domains (:exclude (font-type new-state))
        ui (font-type ui-state)]
    (if (nil? current-domain)
      ()
      (if (some #{current-domain} excluded-domains)
        (configure-addon-for-current-site! (:disable ui))
        (configure-addon-for-current-site! (:enable ui))))))

(defn log [key atom old-state new-state]
  (println "old: " old-state)
  (println "new: " new-state))

(defn domain-name [url] (get (str/split url #"/") 2))

(defn tab-activated [active-info]
  (-> (.get (.-tabs js/browser) (.-tabId active-info))
      (.then #(swap! app-state assoc :current-tab-url (domain-name (.-url %))))))

(defn tab-changed [tab-id change-info tab-info]
  (if (nil? (.-url change-info))
    ()
    (swap! app-state assoc :current-tab-url (domain-name (.-url change-info)))))

(defn browser-action-activated []
  (if (some #{(:current-tab-url @app-state)} (:exclude ((:default-fonts @app-state) @app-state)))
    (swap! app-state
           update-in
           [(:default-fonts @app-state) :exclude]
           (partial remove #{(:current-tab-url @app-state)}))
    (swap! app-state
           update-in
           [(:default-fonts @app-state) :exclude]
           conj
           (:current-tab-url @app-state))))

(defn watch-over-app-state []
  (add-watch app-state :log log)
  (add-watch app-state :write-to-storage! write-to-storage!)
  (add-watch app-state :configure-addon-for-current-site configure-addon-for-current-site))

(defn init []
  (watch-over-app-state)
  (load-state-from-storage!)
  (-> (.query (.-tabs js/browser) (clj->js {:currentWindow true :active true}))
      (.then #(js->clj % :keywordize-keys true))
      (.then first)
      (.then #(:url %))
      (.then domain-name)
      (.then #(swap! app-state assoc :current-tab-url %)))
  )

(.addListener (.-onActivated (.-tabs js/browser)) tab-activated)
(.addListener (.-onUpdated (.-tabs js/browser)) tab-changed)
(.addListener (.-onClicked (.-browserAction js/browser)) browser-action-activated)

(.addListener (.-onInstalled (.-runtime js/browser)) init)
(.addListener (.-onStartup (.-runtime js/browser)) init)
