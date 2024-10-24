import { LightningElement, api } from 'lwc';
import { CommonUtils, LabelService } from "c/utils";

const ESC_KEY_CODE = 27;
const ESC_KEY_STRING = 'Escape';
const TAB_KEY_CODE = 9;
const TAB_KEY_STRING = 'Tab';

export default class ModalPopupBase extends LightningElement {

    labels = LabelService;
    @api title;
    @api isOpen;
    @api size;
    @api isHideBackdrop = false;
    @api setOverflow = false;

    @api openModal() {
        this.isOpen = true;
        this.isFirstRender = true;
    }

    @api closeModal() {
        this.isOpen = false;
    }

    isFirstRender = true;

    get sldsModalContentClass() {
        return CommonUtils.computeClasses(['slds-modal__content', this.setOverflow && 'overflow-initial'])
    }

    get modalCss() {
        const baseCss = 'slds-modal slds-fade-in-open ';
        switch(this.size) {
            case 'customLarge' :
                return CommonUtils.computeClasses([baseCss, 'custom-largeSection', 'slds-modal_large']);
            case 'large':
                return baseCss + 'slds-modal_large';
            case 'medium':
                return baseCss + 'slds-modal_medium';
            case 'base':
                return baseCss;
            default:
                return baseCss + 'slds-modal_small';
        }
    }

    connectedCallback() {
        this.dispatchEvent(new CustomEvent('connected'));
    }

    close() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleRegisterLastElement(event) {
        this.focusOnLastElement = event && event.detail && event.detail.focusOnLastElement;
    }

    handleRegisterFocusElement(event) {
        this.focusElement = event && event.detail && event.detail.focusElement;
    }

    handleFocusOnCrossIcon() {
        const closeButton = this.getCloseButton();
        closeButton && closeButton.focus();
    }

    renderedCallback() {
        const focusElement = this.focusElement && this.focusElement() || this.getCloseButton();
        if (this.isFirstRender && focusElement) {
            this.isFirstRender = false;
            focusElement.focus();
        }
    }

    innerKeyUpHandler(event) {
        if (event.keyCode === ESC_KEY_CODE || event.code === ESC_KEY_STRING) {
            this.close();
        } else if (event.keyCode === TAB_KEY_CODE || event.code === TAB_KEY_STRING) {
            const el = this.template.activeElement;
            let focusableElement;
            if (event.shiftKey && el && el.classList.contains('firstLink')) {
                focusableElement = this.focusOnLastElement && this.focusOnLastElement();
            } else if (el && el.classList.contains('lastLink')) {
                focusableElement = this.getCloseButton();
            }
            if (focusableElement) {
                focusableElement.focus();
            }
        }
    }

    getCloseButton() {
        return this.template.querySelector('lightning-button-icon');
    }
}