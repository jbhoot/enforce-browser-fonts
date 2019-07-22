const browserFonts = Symbol('browser-fonts')
const documentFonts = Symbol('document-fonts')

const {
    browserSettings: { useDocumentFonts },
    browserAction,
    runtime
} = browser

const whichFontsInUse = () => {
    return useDocumentFonts
        .get({})
        .then(res => res.value ? documentFonts : browserFonts)
}

const syncIcon = () => {
    const whichToolbarIconToUse = fontsInUse => {
        return fontsInUse === documentFonts
            ? { icon: 'icons/off.svg', title: 'Using webpage fonts' }
            : { icon: 'icons/on.svg', title: 'Using browser fonts' }
    }

    const syncToolbarIcon = ({ icon, title }) => {
        return Promise.all([
            browserAction.setIcon({ path: icon }),
            browserAction.setTitle({ title: title })
        ])
    }

    return whichFontsInUse()
        .then(whichToolbarIconToUse)
        .then(syncToolbarIcon)
}

const toggleFonts = () => {
    const setFonts = fontsInUse => {
        return useDocumentFonts
            .set({ value: fontsInUse === browserFonts })
    }

    return whichFontsInUse()
        .then(setFonts)
}

runtime.onInstalled.addListener(syncIcon)
runtime.onStartup.addListener(syncIcon)

browserAction.onClicked.addListener(() => {
    return toggleFonts().then(syncIcon)
})