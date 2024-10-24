import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class BdcModal extends LightningModal {
    @api modalData;

    handleNo() {
        this.close();
    }
    handleYes() {
        this.template.querySelector('c-event-passer')?.passEvent(new CustomEvent('success', { bubbles: true, composed: true }));
        this.close();
    }
}