({
    onInit: function (component, event, helper) {
        const workspaceAPI = component.find("workspace");
        const COMMON_CREATE_NEXT = $A.get("$Label.c.COMMON_CREATE_NEXT");
        workspaceAPI.isConsoleNavigation().then(isConsole => {
            if (isConsole) {
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    const focusedTabId = response.tabId;
                    if (response.isSubtab || response.hasOwnProperty('subtabs')) {
                        workspaceAPI.setTabLabel({
                            tabId: response.isSubtab ? focusedTabId : response.subtabs[0].tabId,
                            label: COMMON_CREATE_NEXT
                        });
                        workspaceAPI.setTabIcon({
                            tabId: response.isSubtab ? focusedTabId : response.subtabs[0].tabId,
                            icon: "custom:custom16",
                            iconAlt: COMMON_CREATE_NEXT
                        });
                    }
                });
            }
        });
    },

    reInit : function(component, event, helper) {
        $A.get('e.force:refreshView').fire();
    },

    closeMethodInAuraController : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    }
})