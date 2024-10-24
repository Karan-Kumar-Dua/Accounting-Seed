({
    onInit: function (component, event, helper) {
        const workspaceAPI = component.find("workspace");
        const COMMON_APPLY_CREDIT_MEMO = $A.get("$Label.c.COMMON_APPLY_CREDIT_MEMO");
        workspaceAPI.isConsoleNavigation().then(isConsole => {
            if (isConsole) {
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    const focusedTabId = response.tabId;
                    if (response.isSubtab) {
                        workspaceAPI.setTabLabel({
                            tabId: focusedTabId,
                            label: COMMON_APPLY_CREDIT_MEMO
                        });
                        workspaceAPI.setTabIcon({
                            tabId: focusedTabId,
                            icon: "custom:custom14",
                            iconAlt: COMMON_APPLY_CREDIT_MEMO
                        });
                    }
                    else if (response.hasOwnProperty('subtabs')) {
                        response.subtabs.forEach(item => {
                            workspaceAPI.setTabLabel({
                                tabId: item.tabId,
                                label: COMMON_APPLY_CREDIT_MEMO
                            });
                            workspaceAPI.setTabIcon({
                                tabId: item.tabId,
                                icon: "custom:custom14",
                                iconAlt: COMMON_APPLY_CREDIT_MEMO
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