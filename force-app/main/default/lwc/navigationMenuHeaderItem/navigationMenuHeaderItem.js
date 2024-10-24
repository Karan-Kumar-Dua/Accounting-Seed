import {LightningElement, api, track} from 'lwc';
import {CommonUtils} from 'c/utils';

export default class NavigationMenuHeaderItem extends LightningElement {
    @api menuItem;
    @track isSelected = false;

    @api unselectMenuItem() {
        this.isSelected = false;
    }

    get tabItemClasses() {
        return CommonUtils.computeClasses(['slds-tabs_default__item', this.isSelected && 'slds-is-active']);
    }

    get tabAriaControls() {
        return `tab-default-${this.menuItem.label}`;
    }

    get tabIndex() {
        this.isSelected && '0' || '-1';
    }

    get tabAriaSelected() {
        this.isSelected && 'true' || 'false';
    }

    get tabId() {
        return `tab-default-${this.menuItem.label}__item`;
    }

    mouseenterHandler(event) {
        this.isSelected = true;
        this.dispatchEvent(new CustomEvent('showmenuitembody', { detail: { value: this.menuItem.label } }));
    }

    mouseleaveHandler(event) {
        if (!event.relatedTarget || !event.relatedTarget.dataset || (event.relatedTarget.dataset.id && event.relatedTarget.dataset.id !== this.menuItem.label)) {
            this.isSelected = false;
            this.dispatchEvent(new CustomEvent('hidemenuitembody', { detail: { value: this.menuItem.label } }));
        }
    }
}