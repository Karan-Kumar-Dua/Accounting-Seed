({
    onInit: function (component, event, helper) {
        const workspaceAPI = component.find("workspace");
        const COMMON_FINANCIAL_REPORTS = $A.get("$Label.c.COMMON_FINANCIAL_REPORTS"); 
        workspaceAPI.isConsoleNavigation().then(isConsole => {
            if (isConsole) {
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    const focusedTabId = response.tabId;
                    if (response.isSubtab) {
                        workspaceAPI.setTabLabel({
                            tabId: focusedTabId,
                            label: COMMON_FINANCIAL_REPORTS
                        });
                        workspaceAPI.setTabIcon({
                            tabId: focusedTabId,
                            icon: "standard:account",
                            iconAlt: COMMON_FINANCIAL_REPORTS
                        });
                    }
                    else if (response.hasOwnProperty('subtabs')) {
                        response.subtabs.forEach(item => {
                            workspaceAPI.setTabLabel({
                                tabId: item.tabId,
                                label: COMMON_FINANCIAL_REPORTS
                            });
                            workspaceAPI.setTabIcon({
                                tabId: item.tabId,
                                icon: "standard:account",
                                iconAlt: COMMON_FINANCIAL_REPORTS
                            });
                        })
                    }
                });
            }
        });
    },

    doInit: function(cmp, evt, helper) {},
    reInit : function(component, event, helper) {
        $A.get('e.force:refreshView').fire();
    },

});