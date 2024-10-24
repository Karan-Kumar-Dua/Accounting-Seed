import { LightningElement, api } from 'lwc';
import get1099Info from '@salesforce/apex/X1099InfoHelper.get1099InfoForCD';
import save from '@salesforce/apex/X1099InfoHelper.save1099InfoForCDs';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class X1099InfoCashDisbursements extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api
    get recordIds() {
        return this.selectedRecordIds.join(',');
    }
    set recordIds(val = '') {
        this.selectedRecordIds = val.split(',').filter(x => Boolean(x));
        if (this.selectedRecordIds.length === 1) {
            this.getSelectedRecordValues();
        }
    }

    @api ltngOut = false;

    selectedRecordIds = [];
    selectedFormType;
    selectedFormBox;
    showSpinner = false;

    get recordCount() {
        return this.selectedRecordIds.length;
    }

    formContainer = () => this.template.querySelector('c-x1099-info-form');

    handleCancel() {
        window.history.back();
    }

    handleSave() {
        this.showSpinner = true;
        save({
            recordIds: this.selectedRecordIds,
            form1099TypeId: this.selectedFormType,
            form1099BoxId: this.selectedFormBox
        })
        .then(data => {
            if (data.isSuccess) {
                this.formContainer().showSuccessToast({
                    title: data.successfulRecordCount + ' ' + LabelService.recordsUpdated,
                    messages: []
                });
                setTimeout(() => {
                    window.history.back();
                }, 1500);
            }
            else {
                const failedRecordCount = this.selectedRecordIds.length - data.successfulRecordCount;
                const title = data.successfulRecordCount + ' ' + LabelService.recordsUpdated + ', ' + failedRecordCount  + ' ' + LabelService.recordsFailed;
                this.formContainer().showErrorToast({
                    title: title,
                    messages: data.errors
                });
            }
            this.showSpinner = false;
        })
        .catch(error => {
            this.formContainer().showErrorToast({
                title: LabelService.errorPreventingSave,
                messages: [error.message]
            });
            this.showSpinner = false;
        });
    } 
    
    handleFormChange(event) {
        this.selectedFormType = event.detail.value.type;
        this.selectedFormBox = event.detail.value.box;
    }

    getSelectedRecordValues() {
        this.showSpinner = true;
        get1099Info({
            recordId: this.selectedRecordIds[0]
        })
        .then(data => {
            if (data.isSuccess) {
                this.selectedFormType = data.default1099Type;
                this.selectedFormBox = data.default1099Box;
            } else {
                this.formContainer().showErrorToast({
                    title: LabelService.errorRetrieving1099Data,
                    messages: data.errors
                });
            }
            this.showSpinner = false;
        })
        .catch(error => {
            this.formContainer().showErrorToast({
                title: LabelService.errorRetrieving1099Data,
                messages: [error.message]
            });
            this.showSpinner = false;
        });
    }
    
}