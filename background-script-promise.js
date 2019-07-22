const {
    browserSettings: { useDocumentFonts },
    browserAction,
    runtime
} = browser

const FontSource = {
    browser: 'browser-fonts',
    document: 'document-fonts'
}

const whoseFontsInUse = () => {
    return useDocumentFonts
        .get({})
        .then(res => res.value ? FontSource.document : FontSource.browser)
}

const syncIcon = () => {
    const whichToolbarIconToUse = fontsInUse => {
        return fontsInUse === FontSource.browser
            ? { icon: 'icons/on.svg', title: 'Using browser fonts' }
            : { icon: 'icons/off.svg', title: 'Using webpage fonts' }
    }

    const syncToolbarIcon = ({ icon, title }) => {
        return Promise.all([
            browserAction.setIcon({ path: icon }),
            browserAction.setTitle({ title: title })
        ])
    }

    return whoseFontsInUse()
        .then(whichToolbarIconToUse)
        .then(syncToolbarIcon)
}

const toggleFonts = () => {
    const setFonts = fontsInUse => {
        return useDocumentFonts
            .set({ value: fontsInUse === FontSource.browser})
    }

    return whoseFontsInUse()
        .then(setFonts)
}

runtime.onInstalled.addListener(syncIcon)
runtime.onStartup.addListener(syncIcon)

browserAction.onClicked.addListener(() => {
    return toggleFonts().then(syncIcon)
})