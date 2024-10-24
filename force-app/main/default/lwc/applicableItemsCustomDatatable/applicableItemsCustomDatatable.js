import LightningDatatable from 'lightning/datatable';
import currencyTemplate from './currencyTemplate.html';
import lookupTemplate from './lookupTemplate.html';
import dateTemplate from './dateTemplate.html';
import percentTemplate from './percentTemplate.html';
import urlTemplate from './urlTemplate.html';

export default class ApplicableItemsCustomDatatable extends LightningDatatable  {
    static customTypes = {
        customCurrency: {
            template: currencyTemplate,
            typeAttributes: [
                'disabled',
                'editMode',
                'currencyCode',
                'isMultiCurrencyEnabled',
                'rowId',
                'colId',
                'errors',
                'valueStyle',
                'valueParentheses',
                'valueHideIsoCode',
                'required'
            ]
        },
        customLookup: {
            template: lookupTemplate,
            typeAttributes: [
                'searchObject',
                'searchGroup',
                'searchLimit',
                'searchFilter',
                'selectedName',
                'selectedIcon',
                'hideSelectionIcon',
                'disabled',
                'rowId',
                'colId',
                'errors'
            ]
        },
        customDate: {
            template: dateTemplate,
            typeAttributes: [
                'rowId',
                'colId',
                'errors',
                'disabled',
                'editMode'               
            ]
        },
        customPercent: {
            template: percentTemplate,
            typeAttributes: [
                'maximumFractionDigits',
                'minimumFractionDigits'
            ]
        },
        customUrl: {
            template: urlTemplate,
            typeAttributes: [
                'recordName',
                'showLink'
            ]
        }
    };
}