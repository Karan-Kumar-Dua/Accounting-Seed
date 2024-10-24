import { api, wire, track } from 'lwc';
import { LedgerHierarchy, Ledger, GlAccount } from 'c/sobject';
import { keywords } from 'c/lookupKeywords';
import { NotificationService, ErrorUtils, ModalLightningElement, LabelService } from 'c/utils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import saveRecord from '@salesforce/apex/ConsolidationsHelper.saveRecord';
import Labels from './labels';
import fetchGLAcctDefs from '@salesforce/apex/ConsolidationsHelper.fetchGLAcctDefs';

const REQUIRED_FIELD_MISSING_ERROR_MSG = LabelService.commonCompleteThisField;

export default class ConsolidationCreateHierarchy extends ModalLightningElement {
  @api specificationsByDevNames;
  @api isMultiCurrencyEnabled;

  labels = LabelService;
  ledger = Ledger;
  glAccount = GlAccount;

  ledgerRetrieveFields = {
    [Ledger.objectApiName]: [
      Ledger.type1.fieldApiName
    ]
  };

  ledgerLabel;
  @track ledgerValue;
  ledgerHelp;

  typeLabel;

  notesLabel;
  notesValue;
  showNotes = false;

  showSpinner = false;
  error;
  defaultRecordTypeId;
  ledgerSearchFilter = {
    type: keywords.type.STRING,
    field: Ledger.type1.fieldApiName,
    op: keywords.op.IN,
    val: ['Consolidations-Transactional', 'Consolidations-Budget']
  };
  @track initValues = { isLoaded: true };

  rawLedgerType = '';

  get ledgerType() {
    const type = this.rawLedgerType;
    return type && (type.includes('-') && type.split('-')[1] || type) || '';
  }

  @wire(getObjectInfo, { objectApiName: LedgerHierarchy.objectApiName })
  ledgerHierarchyInfo({data}) {
    if (data) {
      this.defaultRecordTypeId = data.defaultRecordTypeId;
      this.ledgerLabel = this.getFieldFromObjectInfo(LedgerHierarchy.ledger.fieldApiName, data).label;
      this.ledgerHelp = this.getFieldFromObjectInfo(LedgerHierarchy.ledger.fieldApiName, data).inlineHelpText;
      this.typeLabel = this.getFieldFromObjectInfo(LedgerHierarchy.type1.fieldApiName, data).label;
      if (this.getFieldFromObjectInfo(LedgerHierarchy.notes.fieldApiName, data)) {
        this.showNotes = true;
        this.notesLabel = this.getFieldFromObjectInfo(LedgerHierarchy.notes.fieldApiName, data).label;
      }
    }
  }

  registerFocusElement() {
    const self = this;
    this.dispatchEvent(new CustomEvent('registerfocuselement', {
      bubbles: true,
      detail: {
        focusElement: () => {
          return self.template.querySelector('c-lookup-a');
        }
      }
    }));
  }

  getFieldFromObjectInfo = (fieldApiName, objectInfo) => {
    if (objectInfo && objectInfo.fields.hasOwnProperty(fieldApiName)) {
      return objectInfo.fields[fieldApiName];
    }
  }

  handleChange(event) {
    if (event.target.dataset.id === 'ledger') {
      this.rawLedgerType = event.detail && event.detail.recordId && event.detail[this.ledger.type1.fieldApiName] || null;

      this.showSpinner = true;
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
              this.showSpinner = false;
            });
      } else {
        for (const spec of ['Current_Year_Earnings_GL_Account', 'Retained_Earnings_GL_Account', 'CTA_GL_Account']) {
          this.initValues[spec] = null;
        }
        setTimeout(() => {
          this.initValues.isLoaded = true;
          this.showSpinner = false;
        }, 200);
      }
    }
    const lookup = this.template.querySelector(`c-lookup-a[data-id=${event.target.dataset.id}]`);
    lookup && (lookup.cleanErrors(), (event.detail && event.detail.recordId && lookup.reportValidity()));
  }

  notesChange(event) {
    this.notesValue = event.detail.value;
  }

  cancel() {
    this.close();
  }

  save() {
    this.showSpinner = true;
    this.clearErrors();

    const valuesByFields = { notes: this.notesValue };
    const specs2Delete = [];
    const lookups = this.template.querySelectorAll('c-lookup-a');
    for (let lookup of lookups) {
      if (lookup.selection[0] && lookup.selection[0].id) {
        valuesByFields[lookup.dataset.field] = lookup.selection[0] && lookup.selection[0].id;
      } else {
        specs2Delete.push(lookup.dataset.field);
      }
    }

    const { isValid } = this.validateForm();
    !isValid && (this.showSpinner = false);
    isValid && saveRecord({valuesByFields, specs2Delete})
      .then(result => {
        if (!result.errors || !result.errors.length) {
          NotificationService.displayToastMessage(
              this,
              Labels.INF_LEDGER_HIERARCHY_SAVED, 
              LabelService.commonSuccess
          );
          this.close();
        } else {
          const pageErrors = result.errors.filter(error => error.location === 'PAGE');
          pageErrors && pageErrors.length && (this.error = pageErrors[0].msg);

          const fieldErrors = result.errors.filter(error => error.location === 'FIELD');
          fieldErrors && fieldErrors.forEach(fieldError => {
            const lookup = this.template.querySelector(`[data-field=${fieldError.spec}]`);
            lookup && lookup.setCustomValidity(fieldError.msg);
          });
        }
      })
      .catch(e => this.processError(e))
      .finally(() => this.showSpinner = false);
  }

  validateForm() {
    let isValid = true;
    const lookups = this.template.querySelectorAll(`c-lookup-a`);
    lookups.forEach(lookup => {
      lookup.reportValidity() || (isValid = false);
    });

    return { isValid };
  }

  close() {
    this.dispatchEvent(new CustomEvent('close', { bubbles: true }));
  }

  processError(e) {
    if (e.body.output.errors && e.body.output.errors[0]) {
      this.error = e.body.output.errors[0].message;
    } else {
      const { error } = ErrorUtils.processError(e);
      this.error = error;
    }
  }

  clearErrors() {
    this.error = false;
  }
  
}