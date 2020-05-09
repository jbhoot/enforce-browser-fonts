(ns ebf.core
  (:require [clojure.string :as str :refer [split]]))

(def addon-storage (.-local (.-storage js/browser)))

(def config {:browser-fonts  {:enable  {:pref  {:value false}
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

(def state (atom {:default-fonts   :browser-fonts
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


(defn load-from-storage! []
  (println "loading")
  (-> (.get addon-storage)
      (.then #(js->clj % :keywordize-keys true))
      (.then #(swap! state merge %))))

(defn write-to-storage! [key atom old-state new-state]
  (println "storing")
  (->> (select-keys new-state [:default-fonts :browser-fonts :document-fonts])
       (clj->js)
       (.set addon-storage)))

(defn configure-addon-for-current-site [key atom old-state new-state]
  (if (nil? (:current-tab-url new-state))
    ()
    (if (some #{(:current-tab-url new-state)} (:exclude ((:default-fonts new-state) new-state)))
      (configure-addon-for-current-site! (:disable ((:default-fonts new-state) config)))
      (configure-addon-for-current-site! (:enable ((:default-fonts new-state) config))))))

(defn log [key atom old-state new-state]
  (println "old: " old-state)
  (println "new: " new-state))

(add-watch state :log log)
(add-watch state :write-to-storage! write-to-storage!)
(add-watch state :configure-addon-for-current-site configure-addon-for-current-site)

(defn domain-name [url] (get (str/split url #"/") 2))

(defn tab-activated [active-info]
  (-> (.get (.-tabs js/browser) (.-tabId active-info))
      (.then #(swap! state assoc :current-tab-url (domain-name (.-url %))))))

(defn tab-changed [tab-id change-info tab-info]
  (if (nil? (.-url change-info))
    ()
    (swap! state assoc :current-tab-url (domain-name (.-url change-info)))))

(defn browser-action-activated []
  (if (some #{(:current-tab-url @state)} (:exclude ((:default-fonts @state) @state)))
    (swap! state
           update-in
           [(:default-fonts @state) :exclude]
           (partial remove #{(:current-tab-url @state)}))
    (swap! state
           update-in
           [(:default-fonts @state) :exclude]
           conj
           (:current-tab-url @state))))

(.addListener (.-onActivated (.-tabs js/browser)) tab-activated)
(.addListener (.-onUpdated (.-tabs js/browser)) tab-changed)
(.addListener (.-onClicked (.-browserAction js/browser)) browser-action-activated)

(.addListener (.-onInstalled (.-runtime js/browser)) load-from-storage!)
(.addListener (.-onStartup (.-runtime js/browser)) load-from-storage!)
