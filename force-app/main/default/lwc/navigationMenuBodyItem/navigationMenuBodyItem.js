import {LightningElement, api, track} from 'lwc';
import {CommonUtils} from "c/utils";

export default class NavigationMenuBodyItem extends LightningElement {
    @api menuItem;
    @track isShow = false;

    @api showMenuItem() {
        this.isShow = true;
    }

    @api hideMenuItem() {
        this.isShow = false;
    }

    get tabId() {
        return `tab-default-${this.menuItem.label}`;
    }

    get tabAriaLabelledby() {
        return `tab-default-${this.menuItem.label}__item`;
    }

    get tabItemClasses() {
        return CommonUtils.computeClasses(['menu-body-item', 'slds-tabs_default__content', this.isShow && 'slds-show' || 'slds-hide']);
    }

    mouseenterHandler(event) {

    }

    mouseleaveHandler(event) {
        if (!event.relatedTarget || !event.relatedTarget.dataset || event.relatedTarget.dataset.id !== this.menuItem.label) {
            this.hideMenuItem();
            this.dispatchEvent(new CustomEvent('unselectmenuitemheader', { detail: { value: this.menuItem.label } }));
        }
    }
}