import { LightningElement, api } from 'lwc';
import save from '@salesforce/apex/X1099InfoHelper.save';
import getSingleRecordValues from '@salesforce/apex/X1099InfoHelper.getSingleRecordValues';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class UpdateDefault1099Info extends LightningElement {
    labels = {...LabelService, ...Labels};
    enable1099Vendor = true;
    defaultForm1099Type = '';
    defaultForm1099Box = '';
    taxpayerIdentificationNumber = '';
    selectedRecordIds = [];
    isSpinner = false;

    @api 
    set recordIds(val = '') {
        this.selectedRecordIds = val.split(',').filter(x => Boolean(x));
        if (this.selectedRecordIds.length === 1) {
            this.getValues();
        }
    }
    get recordIds() {
        return this.selectedRecordIds.join(',');
    }

    @api 
    ltngOut = false;

    get singleRecord() {
        return this.selectedRecordIds.length === 1;
    }

    get recordCount() {
        return this.selectedRecordIds.length;
    }

    formContainer = () => this.template.querySelector('c-x1099-info-form');

    enable1099VendorChange(event) {
        this.enable1099Vendor = event.target.checked;                
    }

    taxpayerIdentificationNumberChange(event) {
        this.taxpayerIdentificationNumber = event.target.value;
    }

    handleFormChange(event) {
        this.defaultForm1099Type = event.detail.value.type;
        this.defaultForm1099Box = event.detail.value.box;
    }

    handleCancel() {
        window.history.back();
    }

    handleSave() {
        this.isSpinner = true;      
        return save({ 
            recordIds: this.selectedRecordIds,
            enable1099Vendor: this.enable1099Vendor,
            defaultForm1099TypeId: this.defaultForm1099Type,
            defaultForm1099BoxId: this.defaultForm1099Box,
            taxpayerIdentificationNumber: this.taxpayerIdentificationNumber            
        }).then(result => {
            if (result.isSuccess) {
                this.formContainer().showSuccessToast({
                    title: result.successfulRecordCount + ' ' + LabelService.recordsUpdated,
                    messages: []
                });
                setTimeout(() => {
                    window.history.back();
                }, 1500);             
            } else {  
                const failedRecordCount = this.selectedRecordIds.length - result.successfulRecordCount;
                const title = result.successfulRecordCount + ' ' + LabelService.recordsUpdated +  ', ' + failedRecordCount  + ' ' + LabelService.recordsFailed;
                this.formContainer().showErrorToast({
                    title: title,
                    messages: result.errors
                });
            }
            this.isSpinner = false;
        })
        .catch(error => {
            this.formContainer().showErrorToast({
                title: LabelService.errorPreventingSave,
                messages: [error.message]
            });
            this.isSpinner = false;
        });
    }

    getValues() {
        this.isSpinner = true;
        getSingleRecordValues({
            recordId: this.selectedRecordIds[0]
        })
        .then(data => {
            if (data.isSuccess) {
                this.enable1099Vendor = data.X1099Vendor;
                this.taxpayerIdentificationNumber = data.taxpayerId;
                this.defaultForm1099Type = data.default1099Type;
                this.defaultForm1099Box = data.default1099Box;
            } else {
                this.formContainer().showErrorToast({
                    title: LabelService.errorRetrieving1099Data,
                    messages: data.errors
                });
            }
            this.isSpinner = false;
        })
        .catch(error => {
            this.formContainer().showErrorToast({
                title: LabelService.errorRetrieving1099Data,
                messages: [error.message]
            });
            this.isSpinner = false;
        });
    }

}