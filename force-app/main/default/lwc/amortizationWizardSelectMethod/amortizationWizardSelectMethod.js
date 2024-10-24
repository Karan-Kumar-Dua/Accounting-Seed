import {api} from 'lwc';
import WizardItem from 'c/wizardItem';
import {Billing, FixedAsset, Payable} from "c/sobject";
import {LabelService} from "c/utils";
import Labels from './labels';

const SELECT_METHOD_LABELS_BY_SOBJECT_NAMES = {
    [FixedAsset.objectApiName]: LabelService.depreciateWizardSelectMethod,
    [Billing.objectApiName]: LabelService.amortizationWizardSelectMethod,
    [Payable.objectApiName]: LabelService.amortizationWizardSelectMethod
};

export default class AmortizationWizardSelectMethod extends WizardItem {
    @api methodOptions;
    @api sObjectName;
    labels = Labels;

    connectedCallback() {
        this.selectedMethod = this.values.selectedMethod;
    }

    get isMethodOptions() {
        return this.methodOptions && !!this.methodOptions.length
    }

    set selectedMethod(method) {
        this._selectedMethod = method;
    }
    get selectedMethod() {
        return this._selectedMethod || (this.methodOptions && this.methodOptions[0] && this.methodOptions[0].value);
    }

    get selectMethodTitle() {
        return SELECT_METHOD_LABELS_BY_SOBJECT_NAMES[this.sObjectName];
    }

    validateAndRetrieve() {
        return {isValid: !!this.selectedMethod, data: {selectedMethod: this.selectedMethod}};
    }

    handleMethodChange(event) {
        this.selectedMethod = event.detail.value;
    }
}