import {LightningElement, api, track} from 'lwc';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class ExpenseReportLineEditForm extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api expenseReportData;
    @api editMode = false;
    @api expenseLineData;
    @api isMileage = false;

    @track dataLoaded = false;
    @track saveInProgress = false;

    ccVendorId;
    expenseGLAccountId;
    mileageOrigin;
    mileageDestination;
    miles;
    extraFields = [];
    projectId;
    projectTaskId;

    error;
    objectApiName = {"objectApiName":"AcctSeed__Expense_Line__c"};

    get expenseLineId() {
        if (this.expenseLineData) {
            return this.expenseLineData.id;
        }
        return null;
    }

    get expenseTypeOptions() {
        return (this.isMileage) ? this.expenseReportData.mileageExpTypes : this.expenseReportData.expensesExpTypes;
    }

    get isShowCreditCardVendor() {
        return (!this.isMileage && this.expenseReportData.showCreditCardVendor);
    }

    get isCreditCardVendorNotUpdateable() {
        return !this.expenseReportData.isCreditCardVendorUpdateable;
    }

    handleCCVendorSelection(event) {
        this.ccVendorId = event.detail.value;
    }

    handleExpenseTypeSelection(event) {
        this.expenseGLAccountId = event.detail.value;
    }

    handleMileageOriginChange(event) {
        this.mileageOrigin = event.detail.value;
    }

    handleMileageDestinationChange(event) {
        this.mileageDestination = event.detail.value;
    }

    handleMilesChange(event) {
        this.miles = event.detail.value;
    }

    handleCancel() {
        this.fireCloseLightboxEvent();
    }

    fireCloseLightboxEvent() {
        this.dispatchEvent(new CustomEvent('erlformdialogclose'));
    }

    handleFormSuccess() {
        this.error = undefined;
        this.fireCloseLightboxEvent();
        this.fireErlRefreshTableEvent();
    }

    handleError() {
        this.saveInProgress = false;
    }

    handleSave(event) {
        event.preventDefault();
        event.stopPropagation();

        let projectWithTaskSelectionCmp = this.template.querySelector('c-project-with-task-selection');

        if (this.validateCustomInputs(event.detail.fields, projectWithTaskSelectionCmp)) {
            this.saveInProgress = true;
            //get fields populated in form (using input-field elements)
            const fields = event.detail.fields;
            //and add fields populated by custom inputs (not belongs to the form)
            fields.AcctSeed__Expense_Report__c = this.expenseReportData.id;
            fields.AcctSeed__Project__c = projectWithTaskSelectionCmp.getData().projectId;
            fields.AcctSeed__Project_Task__c = projectWithTaskSelectionCmp.getData().projectTaskId;
            fields.AcctSeed__Expense_GL_Account__c = this.expenseGLAccountId;
            if (!this.isMileage) {
                fields.AcctSeed__Credit_Card_Vendor__c = this.ccVendorId;
            }
            fields.AcctSeed__Mileage_Origin__c = this.mileageOrigin;
            fields.AcctSeed__Mileage_Destination__c = this.mileageDestination;
            fields.AcctSeed__Miles__c = this.miles;
            //continue the form submission
            this.template.querySelector('lightning-record-edit-form').submit(fields);
        }
    }

    validateCustomInputs(fieldsInForm, projectWithTaskSelectionCmp) {
        let result = projectWithTaskSelectionCmp.validate();

        if (!this.expenseGLAccountId) {
            let expTypeComboBox = this.template.querySelector("lightning-combobox.expenseType");
            if (expTypeComboBox) {
                expTypeComboBox.reportValidity();
            }
            result = false;
        }

        if (this.isMileage && (this.miles === undefined || this.miles === null)) {
            let milesInput = this.template.querySelector("lightning-input.miles");
            if (milesInput) {
                milesInput.reportValidity();
            }
            result = false;
        }

        if (this.isMileage && (this.mileageOrigin === undefined || this.mileageOrigin === null)) {
            let mileageOriginInput = this.template.querySelector("lightning-input.mileageOrigin");
            if (mileageOriginInput) {
                mileageOriginInput.reportValidity();
            }
            result = false;
        }

        if (this.isMileage && (this.mileageDestination === undefined || this.mileageDestination === null)) {
            let mileageDestinationInput = this.template.querySelector("lightning-input.mileageDestination");
            if (mileageDestinationInput) {
                mileageDestinationInput.reportValidity();
            }
            result = false;
        }

        if (!this.isMileage
                && (this.ccVendorId !== undefined && this.ccVendorId !== null)
                && fieldsInForm.AcctSeed__Employee_Reimburse__c === true) {

            let ccVendorCombobox = this.template.querySelector("lightning-combobox.ccVendor");
            if (ccVendorCombobox) {
                ccVendorCombobox.setCustomValidity(Labels.ERR_EMPLOYEE_CREDIT_CARD_VENDOR);
                ccVendorCombobox.reportValidity();
            }
            result = false;
        }

        return result;
    }

    fireErlRefreshTableEvent() {
        let eventData = {};
        eventData.operation = (this.editMode) ? 'line_update' : 'line_create';
        eventData.data = (this.editMode) ? this.expenseLineData.name : '';
        eventData.selectedTab = (this.isMileage) ? 'mileage' : 'expenses';
        this.dispatchEvent(new CustomEvent('erltablerefresh', {bubbles: true, composed: true, detail: eventData}));
    }

    populateExtraFields(dynamicFields) {
        this.extraFields = [];
        dynamicFields.forEach(function (e) {
            this.extraFields.push({
                fieldPath: e.fieldPath,
                fieldKey: e.label,
                value: this.getDynamicFieldValue(e)
            });
        }, this);
    }

    getDynamicFieldValue(dynamicFieldWrapper) {
        let result = null;
        if (dynamicFieldWrapper.type === 'REFERENCE') {
            result = dynamicFieldWrapper.lookupFieldValue.id;
        }
        if (dynamicFieldWrapper.type === 'BOOLEAN') {
            result = dynamicFieldWrapper.primitiveFieldValue.booleanValue;
        }
        if (dynamicFieldWrapper.type === 'DATE') {
            result = dynamicFieldWrapper.primitiveFieldValue.dateValue;
        }
        if (dynamicFieldWrapper.type === 'NUMBER') {
            result = dynamicFieldWrapper.primitiveFieldValue.decimalValue;
        }
        if (dynamicFieldWrapper.type === 'STRING') {
            result = dynamicFieldWrapper.primitiveFieldValue.stringValue;
        }
        return result;
    }


    connectedCallback() {
        if (this.editMode) {
            this.projectId = this.expenseLineData.project.id;
            this.projectTaskId = this.expenseLineData.projectTask.id;
            this.ccVendorId = this.expenseLineData.creditCardVendor.id;
            this.expenseGLAccountId = this.expenseLineData.expenseType.id;
            this.mileageOrigin = this.expenseLineData.mileageOrigin.stringValue;
            this.mileageDestination = this.expenseLineData.mileageDestination.stringValue;
            this.miles = this.expenseLineData.miles.decimalValue;
            this.populateExtraFields(this.expenseLineData.dynamicFields);
        }
        else {
            this.populateExtraFields(this.expenseReportData.secureLine.dynamicFields);
        }
        this.dataLoaded = true;
    }

}