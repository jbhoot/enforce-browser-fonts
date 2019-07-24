(ns ebf.bg)

; First pass: one big ball of expressions.
; Poor readability but its exhilarating to see the
; 'everything is an expression and returns value' in action
; as well as to see the whole program as a one big expression.
; (.addListener (.-onClicked (.-browserAction js/browser))
;   (fn [_]
;     (.then
;       (.then
;         (.then
;           (.get (.-useDocumentFonts (.-browserSettings js/browser)) #js {})
;           #(.-value %))
;         (fn [doc-fonts?] {:new-fonts (not doc-fonts?) :new-icon (if doc-fonts? "icons/on.svg" "icons/off.svg") :new-tooltip (if doc-fonts? "Browser Fonts" "Document Fonts")}))
;       #(.all js/Promise [(.set (.-useDocumentFonts (.-browserSettings js/browser)) #js {:value (:new-fonts %)})
;                                 (.setIcon (.-browserAction js/browser) #js {:path (:new-icon %)})
;                                 (.setTitle (.-browserAction js/browser) #js {:title (:new-tooltip %)})]))))

; Second pass
; improved readability through thread-first macro
; also improved logic
; (.addListener (.-onClicked (.-browserAction js/browser))
;   (fn [_]
;     (->
;       (.get (.-useDocumentFonts (.-browserSettings js/browser)) #js {})
;       (.then #(.-value %))
;       (.then (fn [doc-fonts?]
;                 (if doc-fonts?
;                   {:doc-fonts? false :icon "icons/on.svg" :tooltip "Browser Fonts"}
;                   {:doc-fonts? true :icon "icons/off.svg" :tooltip "Document Fonts"})))
;       (.then #(.all js/Promise [(.set (.-useDocumentFonts (.-browserSettings js/browser)) #js {:value (:doc-fonts? %)})
;                                 (.setIcon (.-browserAction js/browser) #js {:path (:icon %)})
;                                 (.setTitle (.-browserAction js/browser) #js {:title (:tooltip %)})])))))

; Third pass
; new functionality: sync with current state when the addon is installed as well as at every browser startup.
; more composable, but probably harder to grok at one read?
(defn make-state [doc-fonts?]
  (if doc-fonts?
    {:doc-fonts? true :icon "icons/off.svg" :tooltip "Using Webpage Fonts"}
    {:doc-fonts? false :icon "icons/on.svg" :tooltip "Using Browser Fonts"}))

(defn set-state! [conf]
  (.all js/Promise [(.set (.-useDocumentFonts (.-browserSettings js/browser)) #js {:value (:doc-fonts? conf)})
                    (.setIcon (.-browserAction js/browser) #js {:path (:icon conf)})
                    (.setTitle (.-browserAction js/browser) #js {:title (:tooltip conf)})]))

(defn using-doc-fonts? []
  (-> (.-useDocumentFonts (.-browserSettings js/browser))
    (.get #js {})
    (.then #(.-value %))))

(defn sync-state [invert?]
  (-> (using-doc-fonts?)
    (.then #(make-state (invert? %)))
    (.then #(set-state! %))))

(.addListener (.-onClicked (.-browserAction js/browser)) #(sync-state not))
(.addListener (.-onInstalled (.-runtime js/browser)) #(sync-state identity))
(.addListener (.-onStartup (.-runtime js/browser)) #(sync-state identity))
