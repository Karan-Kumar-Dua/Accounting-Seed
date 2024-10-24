({
    onInit: function (component, event, helper) {
        helper.setVarsFromURL(component);

        const workspaceAPI = component.find("workspace");
        const COMMON_REPORT_VIEWER = $A.get("$Label.c.COMMON_REPORT_VIEWER"); 
        workspaceAPI.isConsoleNavigation().then(isConsole => {
            if (isConsole) {
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    const focusedTabId = response.tabId;
                    if (response.icon === "standard:generic_loading") {
                        workspaceAPI.setTabLabel({
                            tabId: focusedTabId,
                            label: COMMON_REPORT_VIEWER
                        });
                        workspaceAPI.setTabIcon({
                            tabId: focusedTabId,
                            icon: "standard:account",
                            iconAlt: COMMON_REPORT_VIEWER
                        });
                    }
                });
            }
        });
    },

    reInit : function(cmp, event, helper) {
        helper.setVarsFromURL(cmp);
        $A.get('e.force:refreshView').fire();
    }
});