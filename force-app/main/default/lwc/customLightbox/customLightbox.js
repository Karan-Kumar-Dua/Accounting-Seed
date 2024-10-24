import { LightningElement, api } from 'lwc';
import { LabelService} from 'c/utils';

export default class customLightbox extends LightningElement {
    labels = LabelService;
    @api openModal;
    @api headerText;
    
    closeModal() {
        this.openModal = false;
    } 

    closeMethod(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('lightboxcloseclick', {
            cancelable: true            
        }));
        this.closeModal();
    }
}