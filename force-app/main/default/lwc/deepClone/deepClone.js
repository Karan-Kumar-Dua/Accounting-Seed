import { LightningElement, api, track, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { NotificationService, NavigationService, LabelService } from 'c/utils';
import { CloseActionScreenEvent } from 'lightning/actions';
import getDeepCloneInfo from '@salesforce/apex/DeepCloneHelper.getDeepCloneInfo';
import cloneObjectAndLines from '@salesforce/apex/DeepCloneHelper.cloneObjectAndLines';
import Labels from './labels';

const PACKAGE_QUALIFIER = "AcctSeed__";
export default class DeepClone extends NavigationService{
    labels = {...LabelService, ...Labels};
    @api recordId;  
    
    @track infoMessage = LabelService.recurringDeepCloneMessage;
    @track objectInfo;
    @track objectApiName;
    @track fieldNames;
    @track objectLabel;
    @track currentDate;
           
    @wire(getDeepCloneInfo, { recId: '$recordId' })
    wiredGetDeepCloneInfo(result) {
        const { data, error } = result;
        if (data) {
            const record = data;
            this.objectApiName = record.currentObjectName;
            this.currentDate = record.currentDate;
            let fields = record.fieldNames;
            this.fieldNames = [];
            for(const field of fields){
                if(field.includes("Date")){
                    this.fieldNames = [...this.fieldNames, {label: field, isDate: true}];
                }
                else{
                    this.fieldNames = [...this.fieldNames, {label: field, isDate: false}];
                }
            }
        }
        if (error) {
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
        }
    }
    renderedCallback() {
        this.handleFocusOnClone();
    }
    handleFocusOnClone() {
        // set focus with delay, otherwise it will be overridden by something else (browser/lwc) shortly after this function runs.
        setTimeout(() => {
            let cloneButton = this.template.querySelector('lightning-button[data-id="cloneButtonBottom"]');
            cloneButton && cloneButton.focus();
        },1000);
    }
    @wire(getObjectInfo, { objectApiName: '$objectApiName'})
    wiredObjectInfo(data, error){
        if(data){
            this.objectInfo = data;
            if(this.objectInfo.data){
                this.objectLabel = this.objectInfo.data.label;
                this.infoMessage = this.infoMessage.replace("{0}",this.objectLabel);
                this.infoMessage = this.infoMessage.replace("{1}",this.objectLabel);
            }
        }
        if(error){
            NotificationService.displayToastMessage(
                this,
                error.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
        }
    }

    get showSpinner(){
        if(this.infoMessage && this.fieldNames){
            return false;
        }
        else{
            return true;
        }
    }

    handleCancelClick(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCloneClick(){
        let returningValue = this.validateField();
        if(returningValue.status === "valid"){
            let recordMap = {};
            recordMap["attributes"] = {type : this.objectApiName};
            const fieldHolders = this.template.querySelectorAll('lightning-input-field');
            for (let fieldHolder of fieldHolders) {
                recordMap[fieldHolder.fieldName] = fieldHolder.value;
            }       
            let recordString = JSON.stringify(recordMap);
            cloneObjectAndLines({recId : this.recordId, record: recordString})
            .then(result => {
                this.template.querySelectorAll('lightning-button').forEach((item) => {
                    item.label = LabelService.commonProcessing;
                    item.disabled = true;
                });
                this.navigateToEditRecordPageWithBackgroundCtx(result, this.objectApiName);
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            });
        }
        else{   
            let errorMessage = returningValue.message;
            NotificationService.displayToastMessage(
                this,
                errorMessage,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
        }
    }

    validateField(){
        const fieldHolders = this.template.querySelectorAll('lightning-input-field');
        let errorFlag = false;
        let message;
        for (let fieldHolder of fieldHolders) {
            let val = fieldHolder.value;
            if(val === null){
                let fieldLabel = this.objectInfo.data.fields[fieldHolder.fieldName].label;
                message = fieldLabel + ": " + LabelService.errorMustEnterValue;
                errorFlag = true;
                break;
            }
        }
        let returningValue = {};
        if(errorFlag === false){
            returningValue.status = "valid";
        }
        else{
            returningValue.status = "invalid";
            returningValue.message = message;
        }
        return returningValue;
    }
}