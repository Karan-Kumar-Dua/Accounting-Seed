import {LightningElement} from 'lwc';

export default class ModalLightningElement extends LightningElement {
    connectedCallback() {
        this.registerOnFocusOnLastComponent();
        this.registerFocusElement();
    }

    registerOnFocusOnLastComponent() {
        const self = this;
        this.dispatchEvent(new CustomEvent('registerlastelement', {
            bubbles: true,
            detail: {
                focusOnLastElement: () => {
                    const lastFooterBtn = self.template.querySelector('lightning-button:last-child');
                    lastFooterBtn && lastFooterBtn.focus();
                }
            }
        }));
    }

    registerFocusElement() {
        const self = this;
        this.dispatchEvent(new CustomEvent('registerfocuselement', {
            bubbles: true,
            detail: {
                focusElement: () => {
                    return self.template.querySelector('lightning-input');
                }
            }
        }));
    }
}