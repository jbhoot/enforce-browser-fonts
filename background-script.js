const toggle = async () => {
    const {browserSettings: {useDocumentFonts}, browserAction} = browser
    const toggleFrom = await useDocumentFonts.get({})
    const res = await useDocumentFonts.set({value: !toggleFrom.value})
    res && await browserAction.setIcon({path: toggleFrom.value ? 'icons/on.svg' : 'icons/off.svg'})
}

browser.browserAction
    .onClicked
    .addListener(toggle)
