const {
    browserSettings: { useDocumentFonts },
    browserAction,
    runtime
} = browser

const FontSource = {
    browser: 'browser-fonts',
    document: 'document-fonts'
}

const whoseFontsInUse = async () => {
    const res = await useDocumentFonts.get({})
    return res.value ? FontSource.document : FontSource.browser
}

const syncIcon = async () => {
    const whichToolbarIconToUse = fontsInUse => {
        return fontsInUse === FontSource.browser
            ? { icon: 'icons/on.svg', title: 'Using browser fonts' }
            : { icon: 'icons/off.svg', title: 'Using webpage fonts' }
    }

    const syncToolbarIcon = async ({ icon, title }) => {
        await browserAction.setIcon({ path: icon })
        await browserAction.setTitle({ title: title })
    }

    const fontsInUse = await whoseFontsInUse()
    const iconToUse = await whichToolbarIconToUse(fontsInUse)
    await syncToolbarIcon(iconToUse)
}

const toggleFonts = async () => {
    const setFonts = async fontsInUse => {
        await useDocumentFonts
            .set({ value: fontsInUse === FontSource.browser })
    }

    const fontsInUse = await whoseFontsInUse()
    await setFonts(fontsInUse)
}

runtime.onInstalled.addListener(async () => {
    await syncIcon()
})
runtime.onStartup.addListener(async () => {
    await syncIcon()
})

browserAction.onClicked.addListener(async () => {
    await toggleFonts()
    await syncIcon()
})
