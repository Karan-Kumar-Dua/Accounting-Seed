({
    onInit: function (component, event, helper) {
        const workspaceAPI = component.find("workspace");
        const COMMON_TIME_CARD_LINES = $A.get("$Label.c.COMMON_TIME_CARD_LINES");
        workspaceAPI.isConsoleNavigation().then(isConsole => {
            if (isConsole) {
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    const focusedTabId = response.tabId;
                    if (response.isSubtab) {
                        workspaceAPI.setTabLabel({
                            tabId: focusedTabId,
                            label: COMMON_TIME_CARD_LINES
                        });
                        workspaceAPI.setTabIcon({
                            tabId: focusedTabId,
                            icon: "custom:custom18",
                            iconAlt: COMMON_TIME_CARD_LINES
                        });
                    }
                    else if (response.hasOwnProperty('subtabs')) {
                        response.subtabs.forEach(item => {
                            workspaceAPI.setTabLabel({
                                tabId: item.tabId,
                                label: COMMON_TIME_CARD_LINES
                            });
                            workspaceAPI.setTabIcon({
                                tabId: item.tabId,
                                icon: "custom:custom18",
                                iconAlt: COMMON_TIME_CARD_LINES
                            });
                        })
                    }
                });
            }
        });
    },

    reInit : function(component, event, helper) {
        $A.get('e.force:refreshView').fire();
    }
})