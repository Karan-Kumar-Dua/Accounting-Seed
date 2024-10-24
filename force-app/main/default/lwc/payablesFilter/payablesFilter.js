import { LightningElement, api, track } from 'lwc';
import { LabelService } from 'c/utils';
import Labels from './labels';

export default class PayablesFilter extends LightningElement {
    labels = {...LabelService, ...Labels};
    @api errors;
    @api isError = false;
    @api payableNumber;
    @api payeeReference;
    @api postingStatus;
    @api issueDateStart;
    @api issueDateEnd;
    @api dueDateStart;
    @api dueDateEnd;
    @api payableAmountStart;
    @api payableAmountEnd;

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

    handlePayeeReferenceChange(event) {
        this.payeeReference = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handlePayableNumberChange(event) {
        this.payableNumber = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleIssueDateStartChange(event) {
        this.issueDateStart = event.detail.value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handleIssueDateEndChange(event) {
        this.issueDateEnd = event.detail.value;
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

    handlePayableAmountStartChange(event) {
        const value = event.detail.value;        
        this.payableAmountStart = value === "" ? null : value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    handlePayableAmountEndChange(event) {
        const value = event.detail.value;        
        this.payableAmountEnd = value === "" ? null : value;
        this.validate();
        this.valueChangeHandler(event);        
    }

    validate() {
        var payableAmountIsValid = false;
        var datesAreValid = this.validateDateRanges();
        var payableStartFilterIsValid = this.validatePayableFilterUsage("payableAmountStart");
        var payableEndFilterIsValid = this.validatePayableFilterUsage("payableAmountEnd");        
        if (payableStartFilterIsValid && payableEndFilterIsValid) {
            payableAmountIsValid = this.validatePayableAmount();
        }        
        return payableStartFilterIsValid & payableEndFilterIsValid & datesAreValid & payableAmountIsValid;
    }

    validateDateRanges() {
        var isValid = true;
        var dueDateCmp = this.template.querySelector(".dueDateEnd");
        var issueDateCmp = this.template.querySelector(".issueDateEnd");
        if (this.dueDateEnd !== null && this.dueDateEnd !== undefined && this.dueDateStart > this.dueDateEnd) {
            dueDateCmp.setCustomValidity(LabelService.errorEndDateMustBeGreaterThanStart);
            isValid = false;
        } else {
            dueDateCmp.setCustomValidity("");
        }
        dueDateCmp.reportValidity();
        
        if(this.issueDateEnd !== null && this.issueDateEnd !== undefined && this.issueDateStart > this.issueDateEnd){
            issueDateCmp.setCustomValidity(LabelService.errorEndDateMustBeGreaterThanStart);
            isValid = false;
        } else {
            issueDateCmp.setCustomValidity("");            
        }
        issueDateCmp.reportValidity();
        
        return isValid;
    }

    validatePayableAmount() {
        var isValid = false;
        var payableAmountEndCmp = this.template.querySelector(".payableAmountEnd");
        if (parseFloat(this.payableAmountStart) > parseFloat(this.payableAmountEnd)) {
            payableAmountEndCmp.setCustomValidity(LabelService.errorMaxMustBeGreaterThanMin);
        }
        else {
            payableAmountEndCmp.setCustomValidity("");
            isValid = true;
        }
        payableAmountEndCmp.reportValidity();
        return isValid;
    }

    validatePayableFilterUsage(componentName) {
        var isValid = false;
        var inputCmp = this.template.querySelector("." + componentName);
        var payableAmount = 0;
        if (componentName === 'payableAmountStart') {
            payableAmount = this.payableAmountStart;
        } else {
            payableAmount = this.payableAmountEnd;
        }
        if (payableAmount !== null && payableAmount !== undefined &&
            (this.dueDateStart === undefined || this.dueDateStart === null) && 
            (this.dueDateEnd === undefined || this.dueDateEnd === null) && 
            (this.issueDateStart === undefined || this.issueDateStart === null) && 
            (this.issueDateEnd === undefined || this.issueDateEnd === null)) {
            inputCmp.setCustomValidity(Labels.INF_FILTER_BY_PAYABLE_AMOUNT_MUST_FILTER_BY_DUE_OR_ISSUE_DATE);
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
                payeeReference: this.payeeReference,
                payableNumber: this.payableNumber,
                postingStatus: this.postingStatus,
                issueDateStart: this.issueDateStart,
                issueDateEnd: this.issueDateEnd,
                dueDateStart: this.dueDateStart,
                dueDateEnd: this.dueDateEnd,
                payableAmountStart: this.payableAmountStart,
                payableAmountEnd: this.payableAmountEnd,
                validFilter: this.checkValidity()                
            }
        }));
    }


}