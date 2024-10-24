import {LightningElement, api} from 'lwc';
import LOCALE from '@salesforce/i18n/locale';

const DEFAULT_CURRENCY_ISO_CODE = 'USD';

export default class FormattedCurrency extends LightningElement {

    @api
    currencyValue;
    @api
    currencyIsoCode = DEFAULT_CURRENCY_ISO_CODE;
    @api
    isMultiCurrencyOrganization = false;
    @api
    valueParentheses = false;
    @api
    hideIsoCode = false;
    @api
    title;

    @api
    get valueStyle() {
        return this._valueStyle;
    }
    set valueStyle(val = '') {
        this._valueStyle = val;
    }

    get formattedOutput() {
        return this.formatCurrency();
    }

    formatCurrency() {
        const currencyFormat = new Intl.NumberFormat(LOCALE, {
            style: 'currency',
            currency: this.currencyIsoCode || DEFAULT_CURRENCY_ISO_CODE,
            currencyDisplay: this.isMultiCurrencyOrganization ? 'code' : 'symbol'
        });

        let formattedCurrency = '' ;

        if (this.currencyValue != null) {
            formattedCurrency = currencyFormat.format(this.currencyValue);
        }
        let currencySymbolOrCode = formattedCurrency.replace(/(\d|\.|,|-|\s)+/gi, '');
        let codeAndValueSeparator = this.isMultiCurrencyOrganization ? ' ' : '';

        let currencyCode = this.hideIsoCode ? '' : currencySymbolOrCode + codeAndValueSeparator;

        formattedCurrency = formattedCurrency.replace(currencySymbolOrCode, '');
        formattedCurrency = currencyCode + this.getOpenPar() + formattedCurrency.trim() + this.getClosePar();

        return formattedCurrency;
    }

    getOpenPar = () => this.valueParentheses ? '(' : '';
    getClosePar = () => this.valueParentheses ? ')' : '';

}