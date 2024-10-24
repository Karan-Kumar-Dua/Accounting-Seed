import { LightningElement,api,wire } from 'lwc';
import { Ledger, PaymentProcessor, GlAccount, Billing} from "c/sobject";
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import BILLING_OBJECT from '@salesforce/schema/Billing__c';
import { LabelService } from 'c/utils';

const CARDKNOX_TYPE = 'Cardknox';

export default class BillingReceivePaymentFields extends LightningElement {
    labels = LabelService;
    @api wrappedBilling;
    @api paymentInfo;
    @api labels;
    subTotalField;
    subTotalHelpText;
    salesTax2Field;
    salesTax2HelpText;
    salesTax3HelpText;

    @api validateFields() {
        let isValid = true, isAdditionFieldsAreValid = true;
        const inputs = this.template.querySelectorAll(`[data-id]`);
        for (let input of inputs) {
            const isValidInput = this.validate(input?.dataset?.id);
            isValidInput || (isValid = false);
        }

        const element = this.template.querySelector('c-billing-receive-payment-additional-fields');
        isAdditionFieldsAreValid =  element ? element.reportValidity() : true ;

        return (isValid === false || isAdditionFieldsAreValid === false) ? false : true;
    }

    @api retrieveValues() {
        let data = {};
        const inputs = this.template.querySelectorAll(`[data-id]`);
        for (let input of inputs) {
            data[input?.dataset?.id] = input.value;
            if (input?.dataset?.id === 'adjustment-gl-account') {
                const selectedValue = input && input.getSelection() && input.getSelection()[0];
                data[input?.dataset?.id] = selectedValue && (selectedValue.Id || selectedValue.id);
            }
            if (this.isElectronic && this.isCardknoxProcessorSelected) {
                data['bank-account'] = this.merchantGlAccount;
            }
        }
        return data;
    }

    editMode = false;

    ledgerFields = [
        Ledger.nameField,
        Ledger.type1
    ];

    glAccountFields = [
        GlAccount.nameField,
        GlAccount.type,
        GlAccount.bank
    ];

    @wire(getObjectInfo, { objectApiName: BILLING_OBJECT})
    fetchSObjectInfo({ data}) {
        if (data) {
            this.subTotalField = this.getFieldFromObjectInfo(Billing.sub_total.fieldApiName, data).label;
            this.subTotalHelpText = this.getFieldFromObjectInfo(Billing.sub_total.fieldApiName, data).inlineHelpText;
            this.salesTax2Field = this.getFieldFromObjectInfo(Billing.sales_tax2.fieldApiName, data).label;
            this.salesTax2HelpText = this.getFieldFromObjectInfo(Billing.sales_tax2.fieldApiName, data).inlineHelpText;
            this.salesTax3HelpText = this.getFieldFromObjectInfo(Billing.sales_tax3.fieldApiName, data).inlineHelpText;
        }
    }
    getFieldFromObjectInfo = (fieldApiName, objectInfo) => {
        if (objectInfo && objectInfo.fields.hasOwnProperty(fieldApiName)) {
            return objectInfo.fields[fieldApiName];
        }
    }
    paymentProcessor = new PaymentProcessor();

    get ledgerObject () {
        return Ledger.objectApiName;
    }
    get isElectronic() {
        return this.paymentInfo.selectedPaymentType === 'Electronic';
    }
    get paymentTypes() {
        if (!this.paymentInfo.paymentTypes) { return []; }
        let payType = [];
        this.paymentInfo.paymentTypes.forEach(item => {
            if (this.paymentInfo.ignoreElectronic === true && item.value === 'Electronic') {
                return;
            }
            payType.push(item);
        });
        return payType;
    }
 
    get bankAccounts() {
        if (this.wrappedBilling) {
            let tempObj = [];
            Object.keys(this.wrappedBilling.crBankAccounts).forEach(item => {
                tempObj.push({ label: this.wrappedBilling.crBankAccounts[item], value: item });
            }); 
            return tempObj;
        }
        return [];
    }

    get totalAmount() {
        return this.wrappedBilling
            ? (this.wrappedBilling.billTotalBalance - this.wrappedBilling.billCrAdjustment)
            : 0;
    }
    get availablePaymentMethods() {
        if (!this.paymentInfo.paymentDetails.paymentMethodsWithProcessor) { return []; }
        let paymentMethods = [];
        Object.keys(this.paymentInfo.paymentDetails.paymentMethodsWithProcessor).every(item => {
            if (item === this.paymentInfo.paymentDetails.selectedPPId) {
                paymentMethods = this.paymentInfo.paymentDetails.paymentMethodsWithProcessor[item];
                return false;
            }
            return true;
        });
        return paymentMethods;
    }

    get isAdjustmentGLAccountRequired() {
        return this.wrappedBilling && this.wrappedBilling.billCrAdjustment && this.wrappedBilling.billCrAdjustment > 0;
    }

    get isCardknoxProcessorSelected() {
        const processor = this.selectedProcessor();
        if (!processor) { 
            return false; 
        }
        const isCardknoxSelected = processor[this.paymentProcessor.type] === CARDKNOX_TYPE;
        return isCardknoxSelected && this.isElectronic;
    }

    get glAccountObject () {
        return GlAccount.objectApiName;
    }


    get merchantGlAccount() {
        const processor = this.selectedProcessor();
        const merchantGlAccountId = processor[this.paymentProcessor.merchantGlAccount];
        return merchantGlAccountId;
    }
    get salesTaxHelpText() {
        return this.wrappedBilling.isLineLevelPost ? this.salesTax2HelpText : this.salesTax3HelpText;
    }
    selectedProcessor = () => {
        const selectedProcessorId = this.paymentInfo.paymentDetails?.selectedPPId;
        if (!selectedProcessorId) { 
            return null; 
        }
        return this.paymentInfo.paymentDetails.processorRecords.find(p => p.Id === selectedProcessorId);
    }

    validate(dataId) {
        let isValid = true;
        const elem = this.template.querySelector(`[data-id="${dataId}"]`);
        if (elem) {
            switch (elem.dataset.id) {
                case 'bank-account':
                    break;
                case 'discount-amount':
                    break;
                case 'amount':
                    elem.setCustomValidity("");
                    if (elem.value) {
                        (elem.value > (this.wrappedBilling.billTotalBalance - this.wrappedBilling.billCrAdjustment))
                            && (isValid = false, elem.setCustomValidity('Billing cannot be over applied.'));
                        (elem.value < 0) && (isValid = false, elem.setCustomValidity('A negative amount cannot be received.'));
                        ((elem.value * 1) === 0) && (isValid = false, elem.setCustomValidity('Cannot be equal to 0.00'));
                    }
                    !elem.reportValidity() && (isValid = false);
                    break;
                case 'adjustment-gl-account':
                    elem.cleanErrors();
                    isValid = elem.reportValidity();
                    break;
                case 'payment-methods':
                    isValid = elem.reportValidity();
                    break;
                case 'payment-processor':
                    break;
                case 'payment-type':
                    isValid = elem.reportValidity();
                    break;
                case 'payment-date':
                    isValid = elem.reportValidity();
                    break;
                case 'payment-reference':
                    isValid = elem.reportValidity();
                    break;       
            }
        }
        return isValid;
    }

    handleValueChange(event) {
        this.validate(event?.target?.dataset?.id)
        && this.dispatchEvent(new CustomEvent('valuechange', { detail: {
            fieldId: event?.target?.dataset?.id,
            value: (event.detail && event.detail.recordId) || event?.target?.value
        }}));
    }

    handleToggleChange(event) {
        this.dispatchEvent(new CustomEvent('valuechange', { detail: {
            fieldId: event?.target?.dataset?.id,
            value: event.target.checked
        }}));
    }
}