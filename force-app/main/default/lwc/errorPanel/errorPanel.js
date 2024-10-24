import { LightningElement, api, track } from 'lwc';
import { ErrorUtils } from 'c/utils';
import Labels from './labels';

export default class ErrorPanel extends LightningElement {
    /** Generic / user-friendly message */
    @api friendlyMessage = Labels.ERR_RETRIEVING_DATA;
    @api warningMessage;
    
    @track viewDetails = false;
    labels = Labels;

    /** Single or array of LDS errors */
    @api errors;

    get renderAsWarning() {
        return this.warningMessage;
    }

    get errorMessages() {
        return ErrorUtils.reduceErrors(this.errors);
    }

    handleCheckboxChange(event) {
        this.viewDetails = event.target.checked;
    }
}