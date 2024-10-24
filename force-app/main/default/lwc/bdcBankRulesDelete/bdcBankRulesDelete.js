import { api } from 'lwc';
import { ModalLightningElement, LabelService } from "c/utils";
import { deleteRecord } from 'lightning/uiRecordApi';
import Labels from './labels';

export default class BdcBankRulesDelete extends ModalLightningElement {
    labels = {...LabelService, ...Labels};
    @api recordId;
    
    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleConfirm() {
        deleteRecord(this.recordId)
            .then(() => {
                this.dispatchEvent(new CustomEvent('success'));
            })
            .catch(error => {
                this.dispatchEvent(new CustomEvent('error', { detail: { message: error.body.message }}));
            });
    }

}