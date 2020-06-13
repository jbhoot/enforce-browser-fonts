(ns ebf.preferences)

(def pref-state (atom {:default-fonts nil}))

(defn log [key atom old-state new-state]
  (println "old pref: " old-state)
  (println "new pref: " new-state))

(defn update-ui [key atom old-state new-state]
  (if (= (:default-fonts new-state) :browser-fonts)
    (set! (.-checked (.getElementById js/document "browser-fonts")) true)
    (set! (.-checked (.getElementById js/document "document-fonts")) true)))

(defn transmit [key atom old-state new-state]
  (-> (.-runtime js/browser)
      (.sendMessage #js {:message "set-preferences" :data (clj->js new-state)})))

(defn start-event-listeners []
  (.addEventListener (.getElementById js/document "browser-fonts") "change" #(swap! pref-state assoc :default-fonts :browser-fonts))
  (.addEventListener (.getElementById js/document "document-fonts") "change" #(swap! pref-state assoc :default-fonts :document-fonts)))

(defn start-watchers []
  (add-watch pref-state :update-ui update-ui)
  ;(add-watch pref-state :log log)
  (add-watch pref-state :transmit transmit))

(defn initialize-state []
  (-> (.-runtime js/browser)
      (.sendMessage #js {:message "get-preferences" :data #js {}})
      (.then #(js->clj % :keywordize-keys true))
      (.then #(keyword (:default-fonts %)))
      (.then #(swap! pref-state assoc :default-fonts %))))

(defn init []
  (start-watchers)
  (initialize-state)
  (start-event-listeners))

(.addEventListener js/document "DOMContentLoaded" init)
