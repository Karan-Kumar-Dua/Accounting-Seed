import { LightningElement, api, track } from 'lwc';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class X1099InfoForm extends LightningElement {

    labels = {...Labels, ...LabelService};
    @api title = Labels.INF_ENTER_1099_INFORMATION;
    @api recordCount = 0;
    @api spinnerActive = false;
    @api ltngOut = false;

    @api 
    showSuccessToast(opts) {    //{ title = <String>, messages = <String[]> }
        const toast = this.template.querySelector('c-ltng-out-toast-message');
        toast.notifySuccess(opts);
    }

    @api 
    showErrorToast(opts) {      //{ title = <String>, messages = <String[]> }
        const toast = this.template.querySelector('c-ltng-out-toast-message');
        toast.notifyError(opts);
    }

    handleCancel(event) {
        this.preventBubble(event);
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleSave(event) {
        this.preventBubble(event);
        this.dispatchEvent(new CustomEvent('save'));
    }

    preventBubble(event) {
        event.preventDefault();
        event.stopPropagation();
    }

}