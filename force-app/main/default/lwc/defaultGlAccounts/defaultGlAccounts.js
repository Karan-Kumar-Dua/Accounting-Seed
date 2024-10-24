import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { LabelService, NotificationService, KnowledgeBase, CommonUtils, Constants } from 'c/utils';
import { GlAccount, Ledger } from "c/sobject";
import fetchSettings from '@salesforce/apex/DefaultGLAccountsController.fetchSettings';
import fetchDetails from '@salesforce/apex/DefaultGLAccountsController.fetchDetails';
import saveDetails from '@salesforce/apex/DefaultGLAccountsController.saveDetails';
import ledgerDetail from '@salesforce/apex/DefaultGLAccountsController.getLedgerId';
import initialGLAccountDefsCreating from '@salesforce/apex/DefaultGLAccountsController.initialGLAccountDefsCreating';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import GL_ACCOUNT_OBJECT from '@salesforce/schema/GL_Account__c';
import GL_ACCOUNT_NAME_FIELD from '@salesforce/schema/GL_Account__c.Name';
import GL_ACCOUNT_TYPE_FIELD from '@salesforce/schema/GL_Account__c.Type__c';
import GL_ACCOUNT_SUB_TYPE_FIELD from '@salesforce/schema/GL_Account__c.Sub_Type_1__c';
import { keywords } from "c/lookupKeywords";
import Labels from './labels';

const ONLY_TRANSACTIONAL_BUDGET_ERROR = Labels.INF_TRANSACTIONAL_BUDGET_LEDGERS_ALLOWED;

const SKELETON = [
    {
        id: 'Multi-Currency Settings',
        title: LabelService.defaultGlAccountsMultiCurrency,
        isShowSeparator: true,
        isShowSectionDef: (config) => {return config?.multiCurrencyEnabled;}
    },
    {
        id: 'Accounting Close',
        title: LabelService.defaultGlAccountsAccountingClose,
        isShowSeparator: true
    },
    {
        id: 'Accounts Receivable',
        title: LabelService.defaultGlAccountsAccountsReceivable,
        isShowSeparator: true
    },
    {
        id: 'Accounts Payable',
        title: LabelService.defaultGlAccountsAccountsPayable,
        isShowSeparator: true
    },
    {
        id: 'Cash Basis Accounting',
        title: LabelService.defaultGlAccountsCashBasisAccounting,
        isShowSeparator: true
    },
    {
        id: 'Amortize Revenue',
        title: LabelService.defaultGlAccountsAmortizeDetails,
        subtitle: LabelService.defaultGlAccountsAmortizeRevenue,
        isShowSeparator: true
    },
    {
        id: 'Amortize Expense',
        subtitle: LabelService.defaultGlAccountsAmortizeExpense,
        isShowSeparator: false
    },
    {
        id: 'Project Accounting',
        title: LabelService.defaultGlAccountsProjectAccounting,
        isShowSeparator: true
    },
    {
        id: 'Product Costing',
        title: LabelService.defaultGlAccountsProductCosting,
        isShowSeparator: true
    },
    {
        id: 'User Defined',
        title: LabelService.defaultGlAccountsUserDefined,
        isShowSeparator: true,
        isShowSectionDef: (config) => {return config && config.items && config.items.length;}
    }
];

const REVENUE_EXPENSE_AMORTIZATION_LOOKUPS_FILTER = {
    type: keywords.type.STRING,
    field: GlAccount.type.fieldApiName,
    op: keywords.op.NOT_EQUAL,
    val: Constants.GL_ACCT.TYPE_CASH_FLOW
};

const SPECIFICATIONS_BY_LOOKUP_FILTERS = {
    [Constants.GL_ACCOUNT_SPEC.DEV_NAME.CTA_GL_Account]: {
        [keywords.logical.AND] : [
            {field: GL_ACCOUNT_TYPE_FIELD.fieldApiName,
                op: keywords.op.EQUAL,
                val: 'Balance Sheet',
                type: keywords.type.STRING},
            {field: GL_ACCOUNT_SUB_TYPE_FIELD.fieldApiName,
                op: keywords.op.EQUAL,
                val: 'Owners Equity',
                type: keywords.type.STRING}]
    },
    [Constants.GL_ACCOUNT_SPEC.DEV_NAME.Default_Debit_GL_Account_Revenue]: REVENUE_EXPENSE_AMORTIZATION_LOOKUPS_FILTER,
    [Constants.GL_ACCOUNT_SPEC.DEV_NAME.Default_Credit_GL_Account_Revenue]: REVENUE_EXPENSE_AMORTIZATION_LOOKUPS_FILTER,
    [Constants.GL_ACCOUNT_SPEC.DEV_NAME.Default_Debit_GL_Account_Expense]: REVENUE_EXPENSE_AMORTIZATION_LOOKUPS_FILTER,
    [Constants.GL_ACCOUNT_SPEC.DEV_NAME.Default_Credit_GL_Account_Expense]: REVENUE_EXPENSE_AMORTIZATION_LOOKUPS_FILTER
};

export default class DefaultLedger extends LightningElement {

    labels = {...LabelService, ...Labels};

    @track currentPageReference;
    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        this.currentPageReference = currentPageReference;
    }

    @track
    error;

    @track
    sections = [];
    ledgerId = '';
    ledgerApiName = Ledger.objectApiName;
    
    get recordLedgerId() {
        return this.currentPageReference?.state[GlAccount.packageQualifier + 'ledgerId'];
    }

    get isShowMainSection() {
        return this.userCanView && !this.error;
    }

    @wire(ledgerDetail)
    getDefaultLedgerDetail(result) {
        if (result.data) {
            this.ledgerId = result.data;
        }
    }

    @wire (fetchSettings)
    fetchSettingsCallback({data, error}) {
        (data || error) && (this.showSpinner = false);

        if (data) {
            this.ledgerOptions = data.ledgerOptions || [];
            if (this.recordLedgerId && !this.ledgerOptions.find(item => item.value === this.recordLedgerId)) {
                this.error = ONLY_TRANSACTIONAL_BUDGET_ERROR;
            }
            this.selectedLedgerId = this.recordLedgerId || this.ledgerId;
            if (data.defaultWrapsByLedgerIds && !data.defaultWrapsByLedgerIds[this.selectedLedgerId]) {
                this.selectedLedgerId = Object.keys(data.defaultWrapsByLedgerIds)[0];
            }

            this.defaultWrapsByLedgerIds = data.defaultWrapsByLedgerIds;

            this.defaultWraps = this.defaultWrapsByLedgerIds[this.selectedLedgerId];

            this.isGLDefaultRecordsExist = data.isGLDefaultRecordsExist;

            this.specWrapsByTypes = data.specWrapsByTypes;

            this.sections = [...SKELETON].map(section => {
                let items = data.specWrapsByTypes[section.id]
                    ? data.specWrapsByTypes[section.id].map(spec => ({
                        ...spec,
                        lookupFilter: SPECIFICATIONS_BY_LOOKUP_FILTERS[spec.devName],
                        glAccountId: this.defaultWraps && this.defaultWraps[spec.devName].glAccountId
                    }))
                    : [];
                return {
                    ...section,
                    isShowSection: section.isShowSectionDef
                        ? section.isShowSectionDef({multiCurrencyEnabled: data.enablements.multiCurrencyEnabled, items})
                        : true,
                    items
                }
            });
        }

        if (error) {
            let msg;
            if (Array.isArray(error.body)) {
                msg = error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                msg = error.body.message;
            }
            NotificationService.displayToastMessage(
                this,
                msg,
                LabelService.commonToastErrorTitle,
                'error'
            );
        }
    }

    @track
    ledgerOptions;

    @track
    selectedLedgerId;

    @track
    defaultWraps;

    @track
    showSpinner = true;

    /**
     * Page header navigation
     */
    get breadcrumbs () {
        return [
            { title: LabelService.commonAccountingHome,
                tab: `${CommonUtils.getPackageQualifier(GL_ACCOUNT_OBJECT.objectApiName)}Accounting_Home2`},
            { title: LabelService.accountingSetup }
        ];
    }

    get isSelectedLedgerPrimary() {
        return this.ledgerOptions.find(item => item.value === this.selectedLedgerId).isPrimary;
    }

    /**
     * Edit mode on/off
     */
    isEditable = false;

    isModalOpen = false;

    glAccountFields = [
        GL_ACCOUNT_NAME_FIELD,
        GL_ACCOUNT_TYPE_FIELD
    ];

    ledgerFields = [
        Ledger.nameField,
        Ledger.type1
    ];

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        { 
            iconName: 'standard:question_feed', 
            iconAltText: LabelService.knowledgeBase,
            url: KnowledgeBase.defaultGlAccounts
        }
    ];
    
    /**
     * Expose labels to the UI
     */

    /**
     * Object api names
     */

    get glAccountApiName () {
        return GL_ACCOUNT_OBJECT.objectApiName;
    }
 
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

    setGLAccountIds(defaultWraps) {
        defaultWraps = defaultWraps || this.defaultWraps;
        return this.sections.map(section => {
            let items = this.specWrapsByTypes[section.id]
                ? this.specWrapsByTypes[section.id].map(spec => ({
                    ...spec,
                    glAccountId: defaultWraps[spec.devName].glAccountId
                }))
                : [];
            return {
                ...section,
                items
            }
        });
    }

    /**
     * Enables edit mode for the auto-post settings section.
     */
    handleEdit () {
        if (this.isSelectedLedgerPrimary) {
            this.isModalOpen = true;
        }
        else {
            this.isEditable = true;
        }
    }

    /**
     * Discard changes to auto-post settings.
     */
    handleCancel () {
        this.isEditable = false;
        // since we're cloning the settings object when saving,
        // no need to manually reset fields because the rerender
        // will do so for us.
    }

    handleCloseModal() {
        this.handleCancel();
        this.isModalOpen = false;
    }

    handleSubmitModal() {
        this.isEditable = true;
        this.isModalOpen = false;
    }

    handleInitialCreating () {
        this.showSpinner = true;
        initialGLAccountDefsCreating()
            .then((result) => {
                NotificationService.displayToastMessage(
                    this,
                    Labels.INF_RECORDS_CREATED_SUCCESSFUL,
                    LabelService.commonSuccess,
                    'success'
                );
                this.isGLDefaultRecordsExist = true;
                this.defaultWrapsByLedgerIds = {};
            })
            .finally(() => {
                this.retrieveDetails();
            });
    }

    /**
     * Save auto-post settings.
     */
    handleSave () {
        if (this.validateAll()) {
            const inputs = this.template.querySelectorAll('c-lookup-a[data-lookup]');
            let data = [];
            for (let input of inputs) {
                const selectedValue = input.getSelection() && input.getSelection()[0];
                data.push({
                    specDevName: input?.dataset?.lookup,
                    glAccountId: selectedValue && (selectedValue.Id || selectedValue.id),
                    uniqueKey: [input?.dataset?.lookup, this.selectedLedgerId].join(':')
                });
            }

            this.showSpinner = true;
            saveDetails({data, ledgerId: this.selectedLedgerId})
                .then(result => {
                    if (!(result.errors && result.errors.length)) {
                        NotificationService.displayToastMessage(
                            this,
                            LabelService.commonSaveSuccess,
                            LabelService.commonSuccess,
                            'success'
                        );
                        this.defaultWrapsByLedgerIds = {...this.defaultWrapsByLedgerIds, [this.selectedLedgerId]: result.defaultWraps};
                        if (result.shadowLedgerId) {
                            this.defaultWrapsByLedgerIds[result.shadowLedgerId] = result.shadowWraps;
                        }
                        this.defaultWraps = result.defaultWraps;
                        this.sections = this.setGLAccountIds(this.defaultWraps);

                        this.isEditable = false;
                    } else {
                        NotificationService.displayToastMessage(
                            this,
                            result.errors[0].message,
                            LabelService.commonToastErrorTitle,
                            'error'
                        );
                        for (let item of result.errors) {
                            const input = this.template.querySelector(`c-lookup-a[data-lookup="${item.specDevName}"]`);
                            input && input.setCustomValidity(item.message);
                        }
                    }
                })
                .catch(e => {})
                .finally(() => {
                    this.showSpinner = false;
                })
        }
    }

    validateAll() {
        let isValid = true;
        const inputs = this.template.querySelectorAll('c-lookup-a[data-lookup]');
        for (let input of inputs) {
            !this.validate(input?.dataset?.lookup) && (isValid = false);
        }
        return isValid;
    }

    validate(dataLookup) {
        let isValid = true;
        const input = this.template.querySelector(`c-lookup-a[data-lookup="${dataLookup}"]`);
        input && (input.cleanErrors(), isValid = input.reportValidity());
        return isValid;
    }

    handleSelectionChange(event) {
        this.validate(event?.target?.dataset?.lookup);
    }

    handleLedgerChange(event) {
        this.selectedLedgerId = event.detail.value;

        if (!this.defaultWrapsByLedgerIds[this.selectedLedgerId]) {
            this.retrieveDetails();
        } else {
            this.defaultWraps = this.defaultWrapsByLedgerIds[this.selectedLedgerId];
            this.sections = this.setGLAccountIds(this.defaultWraps);
        }
    }

    retrieveDetails() {
        this.showSpinner = true;
        fetchDetails({ledgerId: this.selectedLedgerId})
            .then(result => {
                this.defaultWrapsByLedgerIds = {...this.defaultWrapsByLedgerIds, [this.selectedLedgerId]: result};
                this.defaultWraps = result;
                this.sections = this.setGLAccountIds(this.defaultWraps);
            })
            .catch(e => {})
            .finally(() => {
                this.showSpinner = false;
            });
    }
}