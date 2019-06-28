const {
    browserSettings: {useDocumentFonts},
    browserAction,
    runtime
} = browser

const docFontsInUse = async () => {
    const curr = await useDocumentFonts.get({})
    return curr.value
}

const syncIcon = async () => {
    const curr = await docFontsInUse()
    const icon = curr ? 'icons/off.svg' : 'icons/on.svg'
    await browserAction.setIcon({path: icon})
}

const toggle = async () => {
    const curr = await docFontsInUse()
    await useDocumentFonts.set({value: !curr})
}

runtime.onInstalled.addListener(async () => {
    await syncIcon()
})
runtime.onStartup.addListener(async () => {
    await syncIcon()
})

browserAction.onClicked.addListener(async () => {
    await toggle()
    await syncIcon()
})
