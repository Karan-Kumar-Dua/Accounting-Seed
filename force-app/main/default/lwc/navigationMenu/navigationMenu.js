import {LightningElement, api} from 'lwc';

export default class NavigationMenu extends LightningElement {
    @api menuItems;

    @api
    hideMenuItems(exclusion) {
        let menuHeaderItems = this.template.querySelectorAll(`c-navigation-menu-header-item:not([data-id='${exclusion}'])`);
        menuHeaderItems && menuHeaderItems.forEach(item => item.unselectMenuItem());
        let menuBodyItems = this.template.querySelectorAll(`c-navigation-menu-body-item:not([data-id='${exclusion}'])`);
        menuBodyItems && menuBodyItems.forEach(item => item.hideMenuItem());
    }

    showMenuItemBodyHandler(event) {
        const menuItemLabel = event.detail.value;
        let menuBodyItem = this.template.querySelector(`c-navigation-menu-body-item[data-id='${menuItemLabel}']`);
        menuBodyItem && menuBodyItem.showMenuItem();

        this.hideMenuItems(menuItemLabel);
    }

    hideMenuItemBodyHandler(event) {
        const menuItemLabel = event.detail.value;
        let menuBodyItem = this.template.querySelector(`c-navigation-menu-body-item[data-id='${menuItemLabel}']`);
        menuBodyItem && menuBodyItem.hideMenuItem();
    }

    unselectMenuItemHeaderHandler(event) {
        const menuItemLabel = event.detail.value;
        let menuHeaderItem = this.template.querySelector(`c-navigation-menu-header-item[data-id='${menuItemLabel}']`);
        menuHeaderItem && menuHeaderItem.unselectMenuItem();
    }
}