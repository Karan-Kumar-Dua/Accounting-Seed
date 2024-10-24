import { LightningElement, api, track } from 'lwc';
import { LabelService } from 'c/utils';
import Labels from './labels';

export default class BillingsFilter extends LightningElement {
    labels = {...LabelService, ...Labels};
    @api customer;
    @api customerName;
    @api errors;
    @api isError = false;
    @api billingNumber;
    @api postingStatus;
    @api billingDateStart;
    @api billingDateEnd;
    @api dueDateStart;
    @api dueDateEnd;
    @api billingAmountStart;
    @api billingAmountEnd;

    @track currencyCode = 'USD';  
    @track isMultiCurrencyEnabled = false;
    
    get options() {
        return [
            { label: LabelService.commonPosted, value: 'Posted' },
            { label: LabelService.commonApproved, value: 'Approved' },
            { label: LabelService.commonAll, value: 'All' },
        ];
    }

    handleStatusChange(event) {
        this.postingStatus = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleCustomerChange(event) {
        this.customer = event.detail.value != null && event.detail.value.recordId !== undefined ? event.detail.value.recordId : null;
        this.customerName = event.detail.value != null && event.detail.value.recordName !== undefined ? event.detail.value.recordName : null;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleBillingNumberChange(event) {
        this.billingNumber = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleBillingDateStartChange(event) {
        this.billingDateStart = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleBillingDateEndChange(event) {
        this.billingDateEnd = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleDueDateStartChange(event) {
        this.dueDateStart = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleDueDateEndChange(event) {
        this.dueDateEnd = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleBillingAmountStartChange(event) {
        const value = event.detail.value;        
        this.billingAmountStart = value === "" ? null : value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleBillingAmountEndChange(event) {
        const value = event.detail.value;        
        this.billingAmountEnd = value === "" ? null : value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    validate() {
        var billingAmountIsValid = false;
        var datesAreValid = this.validateDateRanges();
        var billingStartFilterIsValid = this.validateBillingFilterUsage("billingAmountStart");
        var billingEndFilterIsValid = this.validateBillingFilterUsage("billingAmountEnd");        
        if (billingStartFilterIsValid && billingEndFilterIsValid) {
            billingAmountIsValid = this.validateBillingAmount();
        }        
        return billingStartFilterIsValid & billingEndFilterIsValid & datesAreValid & billingAmountIsValid;
    }

    validateDateRanges() {
        var isValid = true;
        var dueDateCmp = this.template.querySelector(".dueDateEnd");
        var billingDateCmp = this.template.querySelector(".billingDateEnd");
        if (this.dueDateEnd !== null && this.dueDateEnd !== undefined && this.dueDateStart > this.dueDateEnd) {
            dueDateCmp.setCustomValidity(LabelService.errorEndDateMustBeGreaterThanStart);
            isValid = false;
        } else {
            dueDateCmp.setCustomValidity("");
        }
        dueDateCmp.reportValidity();
        
        if(this.billingDateEnd !== null && this.billingDateEnd !== undefined && this.billingDateStart > this.billingDateEnd){
            billingDateCmp.setCustomValidity(LabelService.errorEndDateMustBeGreaterThanStart);
            isValid = false;
        } else {
            billingDateCmp.setCustomValidity("");            
        }
        billingDateCmp.reportValidity();
        
        return isValid;
    }

    validateBillingAmount() {
        var isValid = false;
        var billingAmountEndCmp = this.template.querySelector(".billingAmountEnd");
        if (parseFloat(this.billingAmountStart) > parseFloat(this.billingAmountEnd)) {
            billingAmountEndCmp.setCustomValidity(LabelService.errorMaxMustBeGreaterThanMin);
        }
        else {
            billingAmountEndCmp.setCustomValidity("");
            isValid = true;
        }
        billingAmountEndCmp.reportValidity();
        return isValid;
    }

    validateBillingFilterUsage(componentName) {
        var isValid = false;
        var inputCmp = this.template.querySelector("." + componentName);
        var billingAmount = 0;
        if (componentName === 'billingAmountStart') {
            billingAmount = this.billingAmountStart;
        } else {
            billingAmount = this.billingAmountEnd;
        }
        if (billingAmount !== null && billingAmount !== undefined &&
            (this.dueDateStart === undefined || this.dueDateStart === null) && 
            (this.dueDateEnd === undefined || this.dueDateEnd === null) && 
            (this.billingDateStart === undefined || this.billingDateStart === null) && 
            (this.billingDateEnd === undefined || this.billingDateEnd === null) &&
            (this.customer === undefined || this.customer === null)) {
            inputCmp.setCustomValidity(Labels.INF_FILTER_BY_BILLING_AMOUNT);
        } else {
            inputCmp.setCustomValidity("");
            isValid = true;
        }
        inputCmp.reportValidity();
        return isValid;
    }

    checkValidity() {
        const allValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputCmp) => {
                        inputCmp.reportValidity();
                        return validSoFar && inputCmp.checkValidity();
            }, true);
        return allValid;
    }

    valueChangeHandler(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('valuechange', {
            cancelable: true,
            detail: {
                customer: this.customer,
                billingNumber: this.billingNumber,
                postingStatus: this.postingStatus,
                billingDateStart: this.billingDateStart,
                billingDateEnd: this.billingDateEnd,
                dueDateStart: this.dueDateStart,
                dueDateEnd: this.dueDateEnd,
                billingAmountStart: this.billingAmountStart,
                billingAmountEnd: this.billingAmountEnd,
                validFilter: this.checkValidity()                
            }
        }));
    }


}