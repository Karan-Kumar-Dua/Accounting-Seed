import { LightningElement, api } from 'lwc';
import { LabelService } from 'c/utils';

export default class modalPopup extends LightningElement {
    labels = LabelService;
    @api openModal;
    @api popupTitle;
    @api popupSubtitle;
    @api popupBody;
    @api actionButtonText;
    @api cancelButtonText;

    closeModal() {
        this.openModal = false
    } 
    
    cancelMethod(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('modalcancelclick', {
            cancelable: true            
        }));
        this.closeModal();
    }

    saveMethod(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('modalactionclick', {
            cancelable: true            
        }));
        this.closeModal();
    }
}