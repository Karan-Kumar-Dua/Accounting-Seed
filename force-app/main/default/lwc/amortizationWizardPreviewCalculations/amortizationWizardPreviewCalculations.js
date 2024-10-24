import {LightningElement, api, track} from 'lwc';
import invokeFetchCalculations from '@salesforce/apex/AmortizationHelper.fetchCalculations';
import {ErrorUtils, LabelService} from "c/utils";
import LOCALE from '@salesforce/i18n/locale';

const columns = [
    { label: '', fieldName: '', hideDefaultActions: true, cellAttributes: { alignment: 'right' }, fixedWidth: 100},
    { label: '', fieldName: '', hideDefaultActions: true, cellAttributes: { alignment: 'right' }, fixedWidth: 100},
    { label: LabelService.commonPeriods, fieldName: 'period', hideDefaultActions: true, cellAttributes: { alignment: 'left' }, fixedWidth: 102},
    { label: '', fieldName: '', hideDefaultActions: true, cellAttributes: { alignment: 'right' }, fixedWidth: 32},
    { label: LabelService.commonAmounts, fieldName: 'amount', hideDefaultActions: true, cellAttributes: { alignment: 'right' }, fixedWidth: 122},
    { label: '', fieldName: '', hideDefaultActions: true, cellAttributes: { alignment: 'right' }, fixedWidth: 80},
    { label: '', fieldName: '', hideDefaultActions: true, cellAttributes: { alignment: 'right' }, fixedWidth: 100}
];

export default class AmortizationWizardPreviewCalculations extends LightningElement {
    labels = LabelService;
    columns = columns;

    showSpinner = false;
    errors;

    @api currentStep;
    @api isAccountingInfoCreateStep;

    @track data;

    connectedCallback() {
        (this.showSpinner = true) && invokeFetchCalculations({params: this.currentStep})
            .then(result => {
                if (result.isSuccess) {
                    const currencyFormat = new Intl.NumberFormat(LOCALE, {
                        style: 'currency',
                        currency: result.currencyCode,
                        currencyDisplay: result.isMultiCurrencyEnabled ? 'code' : 'symbol'
                    });

                    this.data = result.rows.map(row => ({
                        ...row,
                        amount: this.formatCurrency(row.amount, currencyFormat, result.isMultiCurrencyEnabled)
                    }));
                } else {
                    this.errors = result.errors && result.errors[0];
                }
            })
            .catch(e => this.processError(e))
            .finally(() => {this.showSpinner = false});
    }

    formatCurrency(amount, currencyFormat, isMultiCurrencyEnabled) {
        let formattedCurrency = '';

        if (amount) {
            formattedCurrency = currencyFormat.format(amount);
        }
        let currencySymbolOrCode = formattedCurrency.replace(/(\d|\.|,|-|\s)+/gi, '');
        let codeAndValueSeparator = isMultiCurrencyEnabled ? ' ' : '';

        let currencyCode = currencySymbolOrCode + codeAndValueSeparator;

        formattedCurrency = formattedCurrency.replace(currencySymbolOrCode, '');
        formattedCurrency = currencyCode + formattedCurrency.trim();

        return formattedCurrency;
    }

    goBack() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    createEntries() {
        this.dispatchEvent(new CustomEvent('createentries'));
    }

    processError(e) {
        const {error} = ErrorUtils.processError(e);
        this.errors = error;
    }
}