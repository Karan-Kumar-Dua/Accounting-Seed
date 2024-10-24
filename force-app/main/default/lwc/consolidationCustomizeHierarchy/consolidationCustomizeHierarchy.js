import { api, track, wire } from 'lwc';
import { LedgerHierarchy, Ledger, GlAccount } from "c/sobject";
import saveRecord from '@salesforce/apex/ConsolidationsHelper.saveRecord';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ModalLightningElement, LabelService } from 'c/utils';
import Labels from './labels';
import fetchInitValues from '@salesforce/apex/ConsolidationsHelper.fetchInitValues';
import fetchGLAcctDefs from '@salesforce/apex/ConsolidationsHelper.fetchGLAcctDefs';

const HELP_TEXT = Labels.INF_SORT_ORDER_ROWS_NUMBER;

export default class ConsolidationCustomizeHierarchy extends ModalLightningElement {
    labels = {...LabelService, ...Labels};

    ledger = Ledger;
    glAccount = GlAccount;

    @track hasSpinner = true;
    @track error = {};

    parentLedgerHierarchy = {}; 
    parentLedgerHierarchyName;
    ledgerName;
    lhObjectInfo = {};
    @track initValues = { isLoaded: false };
    sortOrder;
    helpText = HELP_TEXT;
    isValidSortOrder = true;

    @api specificationsByDevNames;
    @api isMultiCurrencyEnabled;

    @api ledgerHierarchyId;
    @api parentLedgerHierarchyId;
    @api parentLedgerHierarchyName;
    @api ledgerHierarchySortOrder = 1;
    @api maxLedgerHierarchySortOrder = 1;

    connectedCallback() {
        fetchInitValues({recordId: this.ledgerHierarchyId})
            .then(result => {
                this.initValues = {...result, isLoaded: true};
            })
            .catch()
            .finally(() => this.hideSpinner());
    }

    @wire(getObjectInfo, { objectApiName: LedgerHierarchy.objectApiName})
    ledgerHierarchyInfo({data,error}){
        if (data) {
            this.lhObjectInfo = {
                ledger: {
                    label: data.fields[LedgerHierarchy.ledger.fieldApiName].label,
                    helpText: data.fields[LedgerHierarchy.ledger.fieldApiName].inlineHelpText,
                    isRequired: data.fields[LedgerHierarchy.ledger.fieldApiName].required
                },
                notes:  {
                    label: data.fields[LedgerHierarchy.notes.fieldApiName].label,
                    helpText: data.fields[LedgerHierarchy.notes.fieldApiName].inlineHelpText,
                    isRequired: data.fields[LedgerHierarchy.notes.fieldApiName].required
                },
                xname:  {
                    label: data.fields[LedgerHierarchy.xname.fieldApiName].label,
                    helpText: data.fields[LedgerHierarchy.xname.fieldApiName].inlineHelpText,
                    isRequired: data.fields[LedgerHierarchy.xname.fieldApiName].required
                },
                sortOrder:  {
                    label: data.fields[LedgerHierarchy.sort_order.fieldApiName].label,
                    helpText: data.fields[LedgerHierarchy.sort_order.fieldApiName].inlineHelpText,
                    isRequired: data.fields[LedgerHierarchy.sort_order.fieldApiName].required
                }
            }
        } 
    }

    registerFocusElement() {
        this.dispatchEvent(new CustomEvent('registerfocuselement', {
            bubbles: true,
            detail: {
                focusElement: null
            }
        }));
    }

    handleChange(event) {
        if (event.target.dataset.id === 'ledger') {
            this.showSpinner();
            this.initValues.isLoaded = false;
            if (event.detail && event.detail.recordId) {
                fetchGLAcctDefs({recordId: event.detail.recordId})
                    .then(result => {
                        for (const [key, value] of Object.entries(result)) {
                            this.initValues[key] = value;
                        }
                    })
                    .finally(() => {
                        this.initValues.isLoaded = true;
                        this.hideSpinner();
                    });
            } else {
                for (const spec of ['Current_Year_Earnings_GL_Account', 'Retained_Earnings_GL_Account', 'CTA_GL_Account']) {
                    this.initValues[spec] = null;
                }
                setTimeout(() => {
                    this.initValues.isLoaded = true;
                    this.hideSpinner()
                }, 200);
            }
        }
        const lookup = this.template.querySelector(`c-lookup-a[data-id=${event.target.dataset.id}]`);
        lookup && (lookup.cleanErrors(), (event.detail && event.detail.recordId && lookup.reportValidity()));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleSortOrder({ detail }) {
        this.sortOrder = detail.value;
        if (!this.sortOrder || this.sortOrder < 1 || this.sortOrder > this.maxLedgerHierarchySortOrder) {
            this.sortOrderCmp().setCustomValidity(`${Labels.INF_ENTER_A_NO_BETWEEN_1_AND} ${this.maxLedgerHierarchySortOrder} ${Labels.INF_TO_CHANGE_THE_ORDER}.`);
            this.isValidSortOrder = false;
        }
        else {
            this.sortOrderCmp().setCustomValidity("");
            this.sortOrderCmp().reportValidity();
            this.isValidSortOrder = true;
        }
    }

    sortOrderCmp = () => this.template.querySelector('.sort-order');

    validateForm() {
        let isValid = true;
        const lookups = this.template.querySelectorAll(`c-lookup-a,[data-field="notes"],[data-field="xname"]`);
        lookups.forEach(lookup => {
            lookup.reportValidity() || (isValid = false);
        });

        this.ledgerHierarchyId && !this.isValidSortOrder && (isValid = false);

        return { isValid };
    }

    handleSave() {
        this.showSpinner();
        this.clearErrors();

        const valuesByFields = {recordId: this.ledgerHierarchyId, parentId: this.parentLedgerHierarchyId};
        const specs2Delete = [];
        const lookups = this.template.querySelectorAll('c-lookup-a');
        for (let lookup of lookups) {
            if (lookup.selection[0] && lookup.selection[0].id) {
                valuesByFields[lookup.dataset.field] = lookup.selection[0] && lookup.selection[0].id;
            } else {
                specs2Delete.push(lookup.dataset.field);
            }
        }
        const inputs = this.template.querySelectorAll('[data-field="notes"],[data-field="xname"]');
        for (let input of inputs) {
            valuesByFields[input.dataset.field] = input.value;
        }
        console.log('valuesByFields: ' + JSON.stringify(valuesByFields));

        const { isValid } = this.validateForm();
        !isValid && (this.hideSpinner());
        isValid && saveRecord({valuesByFields, specs2Delete})
            .then(result => {
                console.log('result: ' + JSON.stringify(result));
                if (!result.errors || !result.errors.length) {
                    this.initValues = { isLoaded: false };
                    const ledgerLookup = this.template.querySelector('[data-field="ledgerId"]');
                    const newLedgerHierarchyName = ledgerLookup && ledgerLookup.selection[0] && ledgerLookup.selection[0].title;

                    this.dispatchEvent(new CustomEvent('success', { detail: {
                            message: this.ledgerHierarchyId && LabelService.commonChangesSaved ||
                                `${newLedgerHierarchyName} ${Labels.INF_ADDED_TO_PARENT_LEDGER}: ${this.parentLedgerHierarchyName}.`,
                            sortOrder : this.sortOrder ? this.sortOrder : this.ledgerHierarchySortOrder,
                            isSaveNew: this.isSaveNew
                        }}));
                } else {
                    const pageErrors = result.errors.filter(error => error.location === 'PAGE');
                    pageErrors && pageErrors.length && (this.error = {msg: pageErrors[0].msg, title: 'Error:'});

                    const fieldErrors = result.errors.filter(error => error.location === 'FIELD');
                    fieldErrors && fieldErrors.forEach(fieldError => {
                        const lookup = this.template.querySelector(`[data-field=${fieldError.spec}]`);
                        lookup && lookup.setCustomValidity(fieldError.msg);
                    });
                }
            })
            .catch()
            .finally(() => this.hideSpinner());
    }

    handleSaveNew() {
        this.isSaveNew = true;
        this.handleSave();
    }

    showSpinner() {
        this.hasSpinner = true;
    }

    hideSpinner() {
        this.hasSpinner = false;
    }

    clearErrors() {
        this.error = {};
    }
}