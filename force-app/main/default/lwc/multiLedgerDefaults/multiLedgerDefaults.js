import { wire, track } from 'lwc';
import {
    LabelService,
    NotificationService,
    NavigationService,
    RecordProxy,
    KnowledgeBase,
    CommonUtils,
    Constants
} from 'c/utils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
import getLedgers from '@salesforce/apex/AccountingSettingsHelper.getTransactionalLedgers';
import saveLedgers from '@salesforce/apex/AccountingSettingsHelper.saveLedgersWithDMLDetails';
import getConfigs from '@salesforce/apex/AccountingSettingsHelper.getConfigs';
import LEDGER_OBJECT from '@salesforce/schema/Ledger__c';
import GL_ACCOUNT_OBJECT from '@salesforce/schema/GL_Account__c';
import GL_ACCOUNT_NAME_FIELD from '@salesforce/schema/GL_Account__c.Name';
import GL_ACCOUNT_TYPE_FIELD from '@salesforce/schema/GL_Account__c.Type__c';
import TAX_SETTINGS_OBJECT from '@salesforce/schema/Tax_Settings__c';
import TAX_SETTINGS_NAME_FIELD from '@salesforce/schema/Tax_Settings__c.Name';
import TAX_SETTINGS_TAX_METHOD_FIELD from '@salesforce/schema/Tax_Settings__c.Tax_Settings_Method__c';
import LEDGER_TAX_SETTINGS_TAX_METHOD_FIELD from '@salesforce/schema/Ledger__c.Tax_Settings__r.Tax_Settings_Method__c';
import PDF_FORMAT_OBJECT from '@salesforce/schema/Billing_Format__c';
import PDF_FORMAT_NAME_FIELD from '@salesforce/schema/Billing_Format__c.Name';
import PDF_FORMAT_TYPE_FIELD from '@salesforce/schema/Billing_Format__c.Type__c';
import PDF_FORMAT_VFPAGE_FIELD from '@salesforce/schema/Billing_Format__c.Visualforce_PDF_Page__c';
import PDF_FORMAT_EMAILTEMPLATE_FIELD from '@salesforce/schema/Billing_Format__c.Default_Email_Template__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import { keywords } from "c/lookupKeywords";
import { GlAccount, BillingFormat } from "c/sobject";

export default class MultiLedgerDefaults extends NavigationService {

    /**
     * Expose labels to the UI
     */
    labels = LabelService;

    @track
    isShowSpinner = true;

    /**
     * Quick access to field labels instead of storing
     * these as custom labels. Wrap these in a proxy that
     * can handle namespaced or non-namespaced records.
     */
    @wire (getObjectInfo, { objectApiName: LEDGER_OBJECT })
    objectInfo({err, data}) {
        if (err) {
            console.error(err);
        }
        if (data) {
            this.ledgerInfo = new RecordProxy(data);
            this.prepareLedger();
        }
    }

    /**
     * Retrieve records and shim them to be used
     * without namespaces.
     */
    @wire (getLedgers)
    ledgerData(response) {
        const {data, error} = response;
        this.ledgerWire = response;
        if (error) {
            console.error(err);
        }
        if (data || error) {
            this.isShowSpinner = false;
        }
        this.ledgerRawData = data;
        this.prepareLedger();
    }

    prepareLedger() {
        if (this.ledgerInfo && this.ledgerRawData && (HAS_READ_PERMISSION || HAS_EDIT_PERMISSION)) {
            const ledgerTaxSettingsTaxMethodParts = LEDGER_TAX_SETTINGS_TAX_METHOD_FIELD.fieldApiName.split('.');
            this.ledgers = this.ledgerInfo.getRecords(this.ledgerRawData)
                .map(ledger => {
                    let originLedger = this.ledgerRawData.find(item => item.Id === ledger.Id);
                    this.getNavigationUrl(ledger.Id).then(url => {
                        let wrapLedger = this.ledgers.find(item => item.record.Id === ledger.Id);
                        wrapLedger && (wrapLedger.url = url);
                    });
                    return {
                        record: ledger,
                        originTaxMethod: originLedger[ledgerTaxSettingsTaxMethodParts[0]] && originLedger[ledgerTaxSettingsTaxMethodParts[0]][ledgerTaxSettingsTaxMethodParts[1]],
                        isSalesTaxCompanyCodeDisabled: !originLedger[ledgerTaxSettingsTaxMethodParts[0]] ||
                            originLedger[ledgerTaxSettingsTaxMethodParts[0]][ledgerTaxSettingsTaxMethodParts[1]] !== Constants.TAX_SETTINGS.TAX_METHOD.AVA_TAX
                    };
                });
        }
    }

    @wire (getConfigs)
    configs;

    @track
    ledgerInfo;

    @track
    ledgers;

    /**
     * Page header navigation
     */
    get breadcrumbs () {
        return [
            { title: LabelService.commonAccountingHome,
                tab: `${this.ledgerInfo?.namespace || CommonUtils.getPackageQualifier(LEDGER_OBJECT.objectApiName)}Accounting_Home2`},
            { title: LabelService.accountingSetup }
        ];
    }

    /**
     * Edit mode on/off
     */
    isEditable = false;

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        {
            iconName: 'standard:question_feed',
            iconAltText: LabelService.commonKnowledgeBase,
            url: KnowledgeBase.multiLedgerDefaults
        }
    ];

    /**
     * Popover fields
     */
    glAccountFields = [
        GL_ACCOUNT_NAME_FIELD,
        GL_ACCOUNT_TYPE_FIELD
    ];

    pdfFormatFields = [
        PDF_FORMAT_NAME_FIELD,
        PDF_FORMAT_TYPE_FIELD,
        PDF_FORMAT_VFPAGE_FIELD,
        PDF_FORMAT_EMAILTEMPLATE_FIELD
    ];

    taxSettingsFields = [
        TAX_SETTINGS_NAME_FIELD,
        TAX_SETTINGS_TAX_METHOD_FIELD
    ];

    searchFilters = {
        defaultBankAccount: {
            type: keywords.type.BOOLEAN,
            field: GlAccount.bank.fieldApiName,
            op: keywords.op.EQUAL,
            val: true
        },
        defaultBillingFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_BILLING
        },
        billingActivityStatementFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_ACTIVITY_STATEMENT
        },
        billingOutstandingStatementFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_OUTSTANDING_STATEMENT
        },
        defaultPackingSlipFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_PACKING_SLIP
        },
        defaultPurchaseOrderFormat: {
            type: keywords.type.STRING,
            field: BillingFormat.type.fieldApiName,
            op: keywords.op.EQUAL,
            val: Constants.BILLING_FORMAT.TYPE_PURCHASE_ORDER
        }
    };

    retrieveFields = {
        [this.taxSettingsObject]: [
            TAX_SETTINGS_TAX_METHOD_FIELD.fieldApiName
        ]
    };

    packageQualifier = CommonUtils.getPackageQualifier(GL_ACCOUNT_TYPE_FIELD.fieldApiName);

    /**
     * Permission checks for UI elements
     */

    get userCanView() {
        // write gives implicit read permission
        return HAS_READ_PERMISSION || HAS_EDIT_PERMISSION;
    }

    get userCanEdit () {
        return HAS_EDIT_PERMISSION;
    }

    get userCannotEdit () {
        return !HAS_EDIT_PERMISSION;
    }

    /**
     * Disable input fields when in read mode.
     */
    get isDisabled () {
        return !this.isEditable || !HAS_EDIT_PERMISSION;
    }

    /**
     * Page has all its necessary data
     */
    get isLoaded () {
        return this.ledgerInfo && this.ledgers;
    }

    /**
     * Getters for objects and fields
     */

    get glAccountObject () {
        return GL_ACCOUNT_OBJECT.objectApiName;
    }

    get pdfFormatObject () {
        return PDF_FORMAT_OBJECT.objectApiName;
    }

    get taxSettingsObject () {
        return TAX_SETTINGS_OBJECT.objectApiName;
    }

    get erpEnabled () {
        return this.configs?.data?.pkgs?.erp?.installed;
    }

    resetSalesTaxCompanyCodeParams({ledger, rowIndex, taxMethod}) {
        if (ledger) {
            ledger.isSalesTaxCompanyCodeDisabled = taxMethod !== Constants.TAX_SETTINGS.TAX_METHOD.AVA_TAX;
            if (ledger.isSalesTaxCompanyCodeDisabled) {
                ledger.record['Sales_Tax_Company_Code__c'] = null;

                const salesTaxCompanyCodeInput = this.template.querySelector(`[data-id="input-salesTaxCompanyCode"][data-index="${rowIndex}"]`);
                salesTaxCompanyCodeInput && (salesTaxCompanyCodeInput.value = null);
                this.validateSalesTaxCompanyCodeInputs([salesTaxCompanyCodeInput]);
            }
        }
    }

    handleSelectionChange(event) {
        const rowIndex = event.currentTarget.dataset.index * 1;
        const ledger = this.ledgers.find((ledger, index) => index === rowIndex);

        event.currentTarget.dataset.id === 'lookup-taxSettings' &&
            this.resetSalesTaxCompanyCodeParams({ledger, rowIndex, taxMethod: (event.detail && event.detail[TAX_SETTINGS_TAX_METHOD_FIELD.fieldApiName])});

        event.currentTarget.errors = [];
    }

    /**
     * Enables edit mode for the auto-post settings section.
     */
    handleEdit () {
        this.isEditable = true;
    }

    /**
     * Discard changes to auto-post settings.
     */
    handleCancel () {
        this.isEditable = false;
        // no need to reset fields, because we're cloning the wire
        // results for use in saving and updating that cloned object
    }

    /**
     * Save auto-post settings.
     */
    handleSave () {
        // deep clone of ledger data
        let ledgerUpdates = JSON.parse(JSON.stringify(this.ledgers.map(ledger => ledger.record)));

        let lookups = [...this.template.querySelectorAll('[data-lookup]')];
        lookups.forEach((lookup) => {
            let selections = lookup.getSelection();
            if (selections.length) {
                ledgerUpdates[lookup.dataset.index][lookup.dataset.lookup] = selections[0].id;
            } else {
                ledgerUpdates[lookup.dataset.index][lookup.dataset.lookup] = null;
            }
        });

        let inputs = [...this.template.querySelectorAll('[data-input]')];
        inputs.forEach((input) => {
           ledgerUpdates[input.dataset.index][input.dataset.input] = input.value;
        });

        // Re-namespace
        ledgerUpdates = this.ledgerInfo.getSObjects(ledgerUpdates);

        if (this.validateSalesTaxCompanyCodeInputs() && this.validateLookups()) {
            this.isShowSpinner = true;

            saveLedgers({
                    ledgers: ledgerUpdates
                }).then((res) => {
                    if (!res.errors || !res.errors.length) {
                        this.isEditable = false;
                        refreshApex(this.ledgerWire);

                        NotificationService.displayToastMessage(
                            this,
                            LabelService.multiLedgerDefaultsSuccess,
                            LabelService.commonSuccess,
                            'success'
                        );
                    } else {
                        res.errors.forEach(error => {
                            if (error.fields?.length) {
                                const ledgerWrapIndex = this.ledgers.findIndex(ledger => ledger.record.Id === error.id);
                                if (~ledgerWrapIndex) {
                                    const ledgerLookup = this.template.querySelector(
                                        `[data-lookup="${error.fields[0]}"][data-id^="lookup"][data-index="${ledgerWrapIndex}"],
                                        [data-lookup="${error.fields[0]?.replace(this.packageQualifier, '')}"][data-id^="lookup"][data-index="${ledgerWrapIndex}"]`
                                    );
                                    ledgerLookup && (
                                        ledgerLookup.setCustomValidity(error.msg)
                                    );
                                }
                            } else {
                                NotificationService.displayToastMessage(
                                    this,
                                    error.msg,
                                    LabelService.commonToastErrorTitle,
                                    'error'
                                );
                            }
                        });
                    }
                }).catch((err) => {
                    NotificationService.displayToastMessage(
                        this,
                        err.body.message || LabelService.multiLedgerDefaultsError,
                        LabelService.commonToastErrorTitle,
                        'error'
                    );
                }).finally(() => {
                    this.isShowSpinner = false;
                });
        }
    }

    handleSalesTaxCompanyCodeChange(event) {
        this.validateSalesTaxCompanyCodeInputs([...this.template.querySelectorAll(
            `[data-input="${event.currentTarget.dataset.input}"][data-id="input-salesTaxCompanyCode"][data-index="${event.currentTarget.dataset.index}"]`
        )])
    }

    validateSalesTaxCompanyCodeInputs(elements) {
        elements = elements || [...this.template.querySelectorAll('[data-id="input-salesTaxCompanyCode"]')];

        let isValid = true;

        elements && elements.forEach(element => {
            const ledgerLookup = this.template.querySelector(`[data-id="lookup-taxSettings"][data-index="${element.dataset.index}"]`);
            const isAvaTax = ledgerLookup && ledgerLookup.selection && ledgerLookup.selection[0] &&
                ledgerLookup.selection[0][TAX_SETTINGS_TAX_METHOD_FIELD.fieldApiName] === Constants.TAX_SETTINGS.TAX_METHOD.AVA_TAX;
            if (element.value || !isAvaTax) {
                element.setCustomValidity('');
            } else if (!element.value && isAvaTax) {
                element.setCustomValidity(LabelService.errorMustEnterValue);
                isValid = false;
            }
            element.reportValidity();
        });

        return isValid;
    }

    validateLookups(elements) {
        elements = elements || [...this.template.querySelectorAll('[data-id^="lookup"]')];

        let isValid = true;

        elements.forEach(element => {
            if (!element.reportValidity()) {
                isValid = false;
            }
        });

        return isValid;
    }
}