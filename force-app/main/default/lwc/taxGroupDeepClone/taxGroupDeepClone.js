import { api, wire } from 'lwc';
import { NavigationService, LabelService } from 'c/utils';
import { TaxGroup } from 'c/sobject';
import { getRecord } from 'lightning/uiRecordApi';
import deepClone from '@salesforce/apex/TaxGroupDeepClone.deepClone';
import Labels from './labels';

const FIELDS = [
    TaxGroup.taxGroupName
];

export default class TaxGroupDeepClone extends NavigationService {
    labels = {...LabelService, ...Labels};
    @api
    recordId;
    taxGroupNameValue;
    error;
    isSpinner = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredTaxGroup({error, data}) {
        if (data) {
            this.taxGroupNameValue = data.fields.Name.value;
        }
    }

    handleNameInput(event) {
        this.taxGroupNameValue = event.target.value;
    }

    handleCloneTaxGroup() {
        this.isSpinner = true;
        this.error = null;
        deepClone({ sourceTaxGroupId: this.recordId, targetTaxGroupName: this.taxGroupNameValue })
            .then((result) => {
                this.navigateToViewRecordPage(result);
            })
            .catch((error) => {
                this.error = error;
                this.isSpinner = false;
            });
    }

    handleTaxGroupDeepCloneDialogClose() {
        this.dispatchEvent(new CustomEvent('tgdc_dialog_close'));
    }

}