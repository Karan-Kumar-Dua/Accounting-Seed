import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ErrorUtils, NotificationService, LabelService } from "c/utils";
import Helper from './bankSettingsHelper';
import getBankSettings from '@salesforce/apex/BankSettingsHelper.getBankSettings';
import fetchAggregationProviders from '@salesforce/apex/BankSettingsHelper.fetchAggregationProviders';
import saveBankSettings from '@salesforce/apex/BankSettingsHelper.saveBankSettings';
import deleteFinancialInstitutionIdentity from '@salesforce/apex/BankSettingsHelper.deleteFinancialInstitutionIdentity';
import registerDeregisterProviders from '@salesforce/apex/BankSettingsHelper.registerDeregisterProviders';
import BankSettingsStore from './bankSettingsStore';
import { loadStyle } from 'lightning/platformResourceLoader';
import staticResource from '@salesforce/resourceUrl/accounting_resources';
import { AccountingSettings } from 'c/sobject';
import hasBDCTransactionAccess from '@salesforce/customPermission/Import_BDC_Transactions';
import LOCALE from '@salesforce/i18n/locale';
import Labels from './labels'

const KEY_FIELD = 'id';
const VALUE_REQUIRED = LabelService.commonValueReq;
const START_DATE_TOO_GREAT = Labels.ERR_INITIAL_START_DATE_TOO_GREAT + ' ';

export default class BankSettings extends NavigationMixin(LightningElement) {

    labels = {...LabelService, ...Labels};
    labels = {...LabelService, ...Labels};
    keyField = KEY_FIELD;
    @api bypassValidation = false;
    
    @track isSpinner = false;
    @track glamColumns = [];
    @api glams = [];
    @track enableAdd = false;

    @track enableMatch = false;
    @track cashInDefaultMatchingSetting;
    @track cashOutDefaultMatchingSetting;
    @track cashInDefaultSourceRecordType;
    @track cashOutDefaultSourceRecordType;
    @track showLightbox = false;   
    @track showPopup = false;   
    @track showCancelPopup = false;   
    @track fullUrl;
    @track selectedFinancialInstitutionId;
    @track selectedFinancialInstitutionIdentityId;
    @track financialInstitutions = [];
    //a map of all available connections (Identities) as a map. Used to populate availableConnections when selecting a new picklist item
    @track connectionIdentityMap;
    //the connection picklist items available for the currently selected financial institution
    @track availableConnections = [];
    @track selectedConnection;
    @track error;
    @track pageErrors;
    @track bankToUnsupportedCurrencies;
    @track isError;
    @track disableButtons = false;
    @track disableButtonsFI = true;
    @track displayFI = false;
    @track prepopulateAccountInfo = false;
    @track providers;
    @track providerValue;
    @track showProviderPopup = false;
    @track showProviderConfirmPopup = false;
    @track provsToRegisterDeRegister;
    @track providerResult;
    @track hasRendered = true;
    @track response;
    @track countries;
    //variable used to hold multi selected countries on UI
    @track selectedCountries;

    glamStore = new BankSettingsStore();  
    isDirty = false;
    accountingSettings = AccountingSettings;  
    
    get cashInDefaultSourceRecordTypeOptions() {
        return [
            { label: LabelService.commonCashReceipts, value: 'Cash Receipt'},
            { label: LabelService.commonJournalEntry, value: 'Journal Entry'}
        ];
    }

    get cashOutDefaultSourceRecordTypeOptions() {
        return [
            { label: LabelService.commonCashDisbursements, value: 'Cash Disbursement'},
            { label: LabelService.commonJournalEntry, value: 'Journal Entry'}
        ];
    }

    connectedCallback() {
        this.showSpinner(true);
        this.glamStore.subscribeMC(this);
        this.loadProviders();
    }

    renderedCallback() {
        if (this.hasRendered) {
            loadStyle(this, staticResource + '/css/grid.css')
                .then(() => {
                    let userLocale = LOCALE.split('-')[1];
                    this.selectedCountries = this.glamStore.getCountryMappings(this).filter(item => item.value === userLocale);
                    this.selectedCountries = this.selectedCountries.length === 0 ? ['US'] : [this.selectedCountries[0].value];
                })
                .catch(e => this.processError(e));
            this.hasRendered = false;
        }

    }

    /**
     * Description - this method should be called after loadProvider() to load the data based on selected provider like Yodlee,plaid etc....
     */
    handleLoadPageData() {
        this.loadGLAMRecords()
            .then(() => {
                this.enableDisableRefreshButton();
                this.showSpinner(false);
            })
            .catch(e => this.processError(e));
    }

    /**
     * method name - loadProviders
     * description - method used for fetch all aggregation providers service.
     */
    async loadProviders() {
        try {
            let result = await fetchAggregationProviders();
            this.providerResult = result;
            this.providers = (result && result.length > 0) ? this.createOptions(result.filter(item => item.AcctSeed__Is_Active__c), 'Name', 'Name') : undefined;
            this.providerValue = (this.providers && this.providers.length > 0) ? this.providers[0].value : undefined;
            if (this.providerValue) {
                this.countries = this.glamStore.getCountryMappings(this);
                this.handleLoadPageData();
            }else{
                this.showSpinner(false);
            }
        } catch (error) {
            this.processError(error);
        }
    }

    /**
    * description - method used for create label value array of object dynamically for combobox.
    * Params - result - an array pf object
    *        - key - key from result array that used to be in label place
    *        - value - key from result array that used to be in value place for combobox
    */
    createOptions(result, key, value) {
        let createdOptions = result.map(item => ({
            label: item[key], value: item[value]
        }));
        return createdOptions;
    }

    /**
    * description - getter to disable enable button reload, save and cancel buttons on UI based on provider availability and record edit access.
    */
    get hasProvAndFI(){
        return !(this.providers && this.providers.length > 0);
    }

    /**
    * description - method used for conditionally render Aggregatipn provider picklist on UI.
    */
    get displayAggregationProvider() {
        return (this.providers && this.providers.length > 0);
    }

    /**
     * description - method used for conditionally render financial institution picklist on UI.
     */
    get displayFinancialInst() {
        return (this.providers && this.displayFI);
    }

    /**
     * description - method used for conditionally render financial institution Identity (i.e connection) picklist on UI.
     */
    get displayFinancialInstIden() {
        return (this.providers && (this.providerValue === this.glamStore.getConstantsValue().PLAID) && this.displayFI && this.availableConnections && this.availableConnections.length > 0);
    }

    get hasBDCAcess() {
        return !hasBDCTransactionAccess;
    }

    /**
     * description - method used for show country picklist on UI when plaid is selected else hide it for other providers like yodlee etc...
    */
    get dispalyCountryPicklist(){
        //if selected provider is not plaid then remove all selected countries with its country field from UI
        this.providerValue !== this.glamStore.getConstantsValue().PLAID ? this.selectedCountries = [] : this.selectedCountries;
        return this.providerValue === this.glamStore.getConstantsValue().PLAID; 
    }

    /**
     * description - shows connection picklist for Plaid
    */
    get displayConnectionPicklist(){
        return this.providerValue === this.glamStore.getConstantsValue().PLAID; 
    }

    /**
     * description - method used for show popup with all register values on click of manage provider button.
     */
    handleManageProvClick() {
        this.showProviderPopup = true;
    }

    /**
    * description - method used for hide popup when click on cross icon of popup.
    */
    closeProviderPopup(event) {
        this.showProviderPopup = event.detail.data;
    }

    /**
    * description - methodcalled when click on save or cancel of provider popup.
    */
    handleProviderClicks(event) {
        switch (event.target.label) {
            case 'Cancel':
                this.showProviderPopup = false;
                return;
            case 'No':
                this.showProviderConfirmPopup = false;
                return;
            case 'Save':
                this.handleProviderSaveConfirmation();
                return;
            default:
        }
    }

    /**
    * description - method called when click on save from popup to show confirmation dialog box.
    */
    handleProviderSaveConfirmation() {
        this.showProviderConfirmPopup = true;
        this.configureConfirmPopupBody();
    }

    /**
    * description - method called when click on yes from confirm popup to register and deregister provider.
    */
    async handleConfrimYes() {
        this.showProviderPopup = false;
        this.showProviderConfirmPopup = false;
        this.showSpinner(true);
        try {
            let response = await this.registerAndDeregisterProvider();
            response = JSON.parse(response);
            if (response.isSuccess === true) {
                if (this.provsToRegisterDeRegister.has('register') && this.provsToRegisterDeRegister.get('register').length > 0) {
                    let successReg = this.provsToRegisterDeRegister.get('register').filter(item => !(response.serviceFaultProviders.includes(item)));
                    if (successReg && successReg.length > 0)
                        NotificationService.displayToastMessage(this, this.labels.REGISTER_SUCCESS_MSG + ' ' + successReg.toString() + '.', LabelService.commonSuccess + ':');
                }
                if (this.provsToRegisterDeRegister.has('deRegister') && this.provsToRegisterDeRegister.get('deRegister').length > 0) {
                    let successDeReg = this.provsToRegisterDeRegister.get('deRegister').filter(item => !(response.serviceFaultProviders.includes(item)));
                    if (successDeReg && successDeReg.length > 0)
                        NotificationService.displayToastMessage(this, this.labels.DEREGISTER_SUCCESS_MSG + ' ' + successDeReg.toString() + '.', LabelService.commonSuccess + ':');
                }
            }
            if (response.serviceFaultProviders.length > 0) {
                NotificationService.displayToastMessage(this, response.faultMessage, LabelService.commonToastErrorTitle + ':', LabelService.commonErrorText);
            }
        } catch (error) {
            NotificationService.displayToastMessage(this, ErrorUtils.processError(error).error, LabelService.commonToastErrorTitle + ':', LabelService.commonErrorText);
        }
        finally {
            this.loadPageData();
        }
    }

    loadPageData() {
        this.loadProviders();
    }

    /**
    * description - method used to register and desrgister service provider.
    */
    async registerAndDeregisterProvider() {
        let isFailed = false;
        let errors;
        let result;
        try {
            let providerResponse;
            // used to prepare array of object to holds register provider
            let providerRegResponse = this.provsToRegisterDeRegister.get('register').map(item =>({
                registerProvider: true,
                deRegisterProvider: false,
                binding: this.providerResult.filter(item1 => item1.Name === item)[0]
            }));
            // used to prepare array of object to holds deregister provider
            let providerDeRegResponse =  this.provsToRegisterDeRegister.get('deRegister').map(item =>({
                registerProvider: false,
                deRegisterProvider: true,
                binding: this.providerResult.filter(item1 => item1.Name === item)[0]
            }));
            // merge both array to send it to apex to register/deregister providers
            providerResponse = [...providerRegResponse, ...providerDeRegResponse];
            //make apex callout here
            result = await registerDeregisterProviders({providerJSON: JSON.stringify(providerResponse)});
        } catch (error) {
            isFailed = true;
            errors = error;
        }
        return new Promise((resolve, reject) => {
            if (isFailed) {
                reject(errors);
            } else {
                resolve(result);
            }
        });
    }

    /**
    * description - method used for prepare body for confirm popup box with list of register and desregister items.
    */
    configureConfirmPopupBody() {
        let regProviderValues = [];
        let deRegProviderValues = [];
        const toggleComp = this.template.querySelectorAll('c-custom-toggle');
        toggleComp.forEach(function (item) {
            if (item.toggleValue !== undefined && item.initialValue !== item.toggleValue) {
                if (item.queryHTMLElement().checked) {
                    regProviderValues.push(item.providervalue.Name);
                } else {
                    deRegProviderValues.push(item.providervalue.Name);
                }
            }
        });

        this.provsToRegisterDeRegister = new Map();
        this.provsToRegisterDeRegister.set('register', regProviderValues);
        this.provsToRegisterDeRegister.set('deRegister', deRegProviderValues);

        setTimeout(() => {
            if (regProviderValues.length > 0) {
                this.createRegisterWarining(true);
                this.configureRegisterMsge(regProviderValues);
            }
            if (deRegProviderValues.length > 0) {
                this.createRegisterWarining(false);
                this.configureRegisterMsge(deRegProviderValues);
            }
        }, 1);

    }

    configureRegisterMsge(providersValues) {
        try {
            const div = this.template.querySelector('.provMsg');
            let ul = document.createElement('ul');
            ul.setAttribute('class', 'slds-list_dotted');
            div.appendChild(ul);
            providersValues.forEach(item => {
                let li = document.createElement('li');
                li.innerHTML = item;
                ul.appendChild(li);
            });
            let br = document.createElement("br");
            ul.parentNode.insertBefore(br, ul.nextSibling);
        } catch (error) {
            this.processError(error);
        }
    }

    /**
     * description - method used for create register and deregister warnings.
     */
    createRegisterWarining(isRegister) {
        let constantValues = this.glamStore.getConstantsValue();
        const div = this.template.querySelector('.provMsg');
        let bold = document.createElement('b');
        bold.innerHTML = isRegister ? constantValues.REGISTER_MSG : constantValues.DEREGISTER_MSG;
        div.appendChild(bold);
    }

    /**
    * description - method called when toggle switches to disable and enable the manage aggregation provider popup save button.
    */
    handleToggle() {
        const toggleComp = this.template.querySelectorAll('c-custom-toggle');
        let toggleVals = [];
        toggleComp.forEach(item => {
           if( item.toggleValue !== undefined){
            toggleVals.push(item.initialValue ===  item.toggleValue)
           }
        });
        let disableButton = toggleVals.some(item => item === false);
        let saveBtn = this.template.querySelector('lightning-button[data-id="saveToggleBtn"]');
        if (saveBtn) {
            saveBtn.disabled = !(disableButton);
        }
    }

    /**
    * description - method used to enable/disable refresh button while plaid is selected it will be disble.
    */
    enableDisableRefreshButton() {
        let financialInstitutions = this.response?.mFinancialInstitutitonBySource[this.providerValue];
        let refButton = this.template.querySelector('.refreshFI');
        setTimeout(() => {
            if (this.providerValue === this.glamStore.getConstantsValue().PLAID || (!(financialInstitutions && financialInstitutions.length > 0))) {
                refButton.disabled = true;
            } else {
                refButton.disabled = false;
            }
        }, 1);
    }
    
    /*
    *  returns a map of yodlee financial institutions to corresponding identities
    *  Only used for Yodlee since the fin inst and identities are 1-1
    *  returns a map of all Yodlee financial institution to their corresponding identities
    */
    getFinancialInstitutionToIdentityMap() {
        let finInstToFinInstIden;
        for (let aFinInstIden in this.mFinInstIdentity.values()) {
            if (aFinInstIden.source === this.glamStore.getConstantsValue().INF_YODLEE) {
                finInstToFinInstIden[aFinInstIden.financialInstitutionId] = aFinInstIden.id;
            }
        }
        return finInstToFinInstIden;
    }

    /**
    * description - method used to hold the selected country value.
    */
    handlecountryChange(event) {
        this.selectedCountries ? this.selectedCountries : this.selectedCountries = [];
        this.selectedCountries = event.detail.value;
    }

    /**
    * description - method used to hold the selected provider value.
    */
    handleProviderSelection(event) {
        this.providerValue = event.detail.value;
        this.processFinancialInstitutions(this.response);
        this.enableDisableRefreshButton();
    }

    prepopulateAccountInfoChange(event) {
        this.prepopulateAccountInfo = event.detail.checked;     
        this.setIsDirtyStatus(true);
    }

    enableMatchChange(event) {
        this.enableMatch = event.target.checked;     
        this.setIsDirtyStatus(true);   
    }

    enableAddChange(event) {
        this.enableAdd = event.target.checked;        
        this.setIsDirtyStatus(true);
    }

    /*
    *  given a list of identities and a financial institution id, return only the identities associated with the given institution
    */
    filterIdentitiesForFinancialInstitution(allConnectionIdentities, financialInstId) {
        let connectionsForInstitution = [];
        for (let connectionCounter = 0; connectionCounter < allConnectionIdentities.length; connectionCounter++) {
            if (allConnectionIdentities[connectionCounter].financialInstitutionId === financialInstId) {
                connectionsForInstitution.push(allConnectionIdentities[connectionCounter]);
            }
        }
        return connectionsForInstitution;
    }

    selectedFinancialInstitutionIdChange(event) {
        this.selectedFinancialInstitutionId = event.target.value;
        //For Plaid, select the first connection (identity) for the financial institution by default
        if (this.providerValue === this.glamStore.getConstantsValue().PLAID) {
            let connectionsForSelectedInstitution = this.filterIdentitiesForFinancialInstitution(Object.values(this.connectionIdentityMap), this.selectedFinancialInstitutionId);
            this.availableConnections = this.createOptions(connectionsForSelectedInstitution, 'identityName', 'id');
            this.selectedConnection = this.availableConnections[0].value;
            this.selectedFinancialInstitutionIdentityId = this.selectedConnection;
        }
        //for yodlee, get the identity Id and set it as the fin inst and fin inst Identity are 1-1
        else if (this.providerValue === this.glamStore.getConstantsValue().YODLEE) {
            this.selectedFinancialInstitutionIdentityId = this.getFinancialInstitutionToIdentityMap()[this.selectedFinancialInstitutionId];
            this.selectedConnection = null;
        }
    }

    selectedFinancialInstitutionIdentityIdChange(event) {
        this.selectedFinancialInstitutionIdentityId = event.target.value;
    }

    cashInDefaultMatchingSettingChange(event) {
        this.cashInDefaultMatchingSetting = event.target.value;
        this.setIsDirtyStatus(true);

    }

    cashOutDefaultMatchingSettingChange(event) {
        this.cashOutDefaultMatchingSetting = event.target.value;
        this.setIsDirtyStatus(true);
    }

    cashInDefaultSourceRecordTypeChange(event) {
        this.cashInDefaultSourceRecordType = event.detail.value;
        this.setIsDirtyStatus(true);
    }

    cashOutDefaultSourceRecordTypeChange(event) {
        this.cashOutDefaultSourceRecordType = event.detail.value;
        this.setIsDirtyStatus(true);
    }

    lightboxCloseEvent(){
        this.showLightbox = false;
        this.handleRefreshingGridAfterFIChanges();
    }

    iframeOnload(){
        this.showSpinner(false);
    }

    popupSaveEvent(){
        this.showPopup = false;
        this.showSpinner(true);
        return deleteFinancialInstitutionIdentity({
            bdcBindingDevName: this.providerValue,
            financialInstitutionIdentityId: this.selectedFinancialInstitutionIdentityId
        }).then(result => {
            this.loadGLAMRecords().then(() => {
                this.showSpinner(false);
                NotificationService.displayToastMessage(this, Labels.INF_FINANCIAL_INSTITUTION_DELETED, Labels.INF_DELETE_SUCCESSFUL);
                this.error = null;
            });
        })
        .catch(error => {
            this.showSpinner(false);
            this.error = Labels.ERR_DURING_DELETE;
            if (Array.isArray(error.body)) {
                this.error = error.body.map(e => e.message).join (', ');
            } else if (typeof error.body === 'string') {
                this.error = error.body;
            }
            
        });
    }
    
    popupCancelEvent(){
        this.showPopup = false;
    }

    popupCancelYesEvent(){
        this.showCancelPopup = false;
        this.showSpinner(true);
            this.loadGLAMRecords().then(() => {
                this.resetValidity();
                this.showSpinner(false);
        }); 
    }
    
    popupCancelNoEvent(){
        this.showCancelPopup = false;
    }

    /**
     * Description - method calls when click on new Button to show selected provider bank link screen
     */
    handleNewFI() {
        this.showSpinner(true);
        this.fullUrl = this.glamStore.getProviderFILink(this.providerValue, this.providers); 
        let countriesString = '';
        this.selectedCountries.forEach((country) => {
            countriesString += JSON.stringify(country).replace(/['"]+/g, '') + ',';
        });
        countriesString = countriesString.substring(0, countriesString.length - 1);
        
            
        this.fullUrl =  this.fullUrl + '?countries=' + countriesString;
        if (this.providerValue === this.glamStore.getConstantsValue().PLAID) {
            this.openSitePage('standard__webPage', {url:this.fullUrl});
            return;
        }
        this.showLightbox = true;
    }

    handleEditFI() {
        this.fullUrl = this.glamStore.getProviderFILink(this.providerValue, this.providers);
        if (this.providerValue === this.glamStore.getConstantsValue().PLAID) {
            this.openSitePage('standard__webPage', {url:this.fullUrl+'?params='+this.selectedFinancialInstitutionIdentityId});
            return;
        }
        this.fullUrl =  this.fullUrl+'?params=' + this.selectedFinancialInstitutionIdentityId + '&action=edit';
        this.showSpinner(true);
        this.showLightbox = true;
    }

    handleRefreshFI() {
        this.showSpinner(true);
        this.fullUrl = '/apex/AcctSeed__FastLink?params=' + this.selectedFinancialInstitutionIdentityId + '&action=refresh';
        this.showLightbox = true;
    }

    handleDeleteFI() {
        if (this.providerValue === this.glamStore.getConstantsValue().PLAID) {
            this.popupSaveEvent();
            return;
        }
        this.showPopup = true;        
    }

    handleCancelClick() {
        if (this.isDirty === true || (this.glamStore.getItems() !== undefined && this.glamStore.getChanges().length > 0)) {
            this.showCancelPopup = true;
        } else {
            this.showSpinner(true);
            this.loadGLAMRecords().then(() => {
                this.resetValidity();
                this.showSpinner(false);
            });     
        }   
    }

    handleRefreshClick() {
        this.handleRefreshingGridAfterFIChanges();
    }

    handleRefreshingGridAfterFIChanges() {        
        this.errors = [];
        this.showSpinner(true);
        this.loadGLAMRecords()
        .then(() => {
            this.enableDisableRefreshButton();
            this.showSpinner(false);
        });
    }

    save() {
        let singleFIAFld = this.template.querySelector('lightning-input[data-id="FIAbox"]');
        return saveBankSettings({ 
                            enableAdd: this.enableAdd === 'checked' ? true : this.enableAdd,
                            enableMatch: this.enableMatch === 'checked' ? true : this.enableMatch,
                            cashInDefaultMatchingSetting: this.cashInDefaultMatchingSetting,
                            cashOutDefaultMatchingSetting: this.cashOutDefaultMatchingSetting,
                            cashInDefaultSourceRecordType: this.cashInDefaultSourceRecordType,
                            cashOutDefaultSourceRecordType: this.cashOutDefaultSourceRecordType,
                            updatedGlams: this.glamStore.getItems() !== undefined ? this.stringifyEach(this.glamStore.getChanges()) : null,
                            prepopulateAccountInfo: this.prepopulateAccountInfo,
                            singleFIA: singleFIAFld ? singleFIAFld.checked : false
                }).then(result => {
                    if (result.isSuccess) {
                        this.loadGLAMRecords().then(() => {
                        this.showSpinner(false);
                        NotificationService.displayToastMessage(this, LabelService.commonChangesSaved, LabelService.commonSaveSuccessful);
                        this.error = null;
                    });                
                    } else {                
                        this.error = result.errors;
                        this.showSpinner(false);
                    }
                })
                .catch(error => {
                    this.showSpinner(false);
                    this.error = LabelService.commonErrorDuringSave;
                    if (Array.isArray(error.body)) {
                        this.error = error.body.map(e => e.message).join (', ');
                    } else if (typeof error.body === 'string') {
                        this.error = error.body;
                    }                
                });
    }

    handleSaveClick() {
        this.showSpinner(true);
        let allVaild = false;
        if (this.isDataGridValid() && this.isFieldsValid()) {
            allVaild = true;
        } else {
            this.showSpinner(false);
            this.error = Labels.ERR_ON_THE_PAGE_RESOLVE;
            return;
        }
        if(allVaild){
            this.save();
        }

    }

    loadGLAMRecords() {
        return getBankSettings()
            .then(results => this.initializeBankSettingsErrors(results))
            .then(results => this.processAccountSettings(results))
            .then(results => this.processGLAMRecords(results))
            .then(results => this.processFinancialInstitutions(results))
            .then(() => this.initColumns())
            .then(() => this.setIsDirtyStatus(false))
            .then(() => this.processPageErrors())
            .catch(e => this.processError(e));
            
    }

    processAccountSettings(results) {
        this.response = results;
        this.cashInDefaultMatchingSetting = results.cashInDefaultMatchingSetting;       
        this.cashOutDefaultMatchingSetting = results.cashOutDefaultMatchingSetting;       
        this.cashInDefaultSourceRecordType = results.cashInDefaultSourceRecordType;
        this.cashOutDefaultSourceRecordType = results.cashOutDefaultSourceRecordType;
        this.enableAdd = results.enableAdd === true ? 'checked' : false;
        this.enableMatch = results.enableMatch === true ? 'checked' : false;  
        this.disableButtons = results.allowEdit === true ? false : 'disabled';
        this.disableButtonsFI = this.disableButtons;
        this.prepopulateAccountInfo = results.prepopulateAccountInfo;
        return results;      
    }

    processGLAMRecords(results) {
        this.error = null;
        this.glamStore.setItems(results.glams);
        this.glamStore.handleLegacyLedgers();        
        this.glams = this.glamStore.getItems();          
        return results;     
    }

    processFinancialInstitutions(results) {
        let financialInstitutions = results?.mFinancialInstitutitonBySource[this.providerValue];
        this.connectionIdentityMap = results?.mFinInstIdentity;
        if (financialInstitutions && financialInstitutions.length > 0) {
            this.setFIOptions(financialInstitutions);
            this.selectedFinancialInstitutionId = financialInstitutions[0].id; 
            this.displayFI = true;
            if (!this.disableButtons) {
                this.disableButtonsFI = false;                
            }
            this.selectedFinancialInstitutionIdentityId = this.availableConnections[0].value;
        } else {
            this.selectedFinancialInstitutionIdentityId = '';
            this.disableButtonsFI = true;
            this.displayFI = false;
        }
        return results;
    }

    //initialize errors returned by the page. They will not necessarily stop execution.
    initializeBankSettingsErrors(results) {

        this.pageErrors = results.pageErrors;
        this.bankToUnsupportedCurrencies = results.bankToUnsupportedCurrencies;
        return results;
    }

    //called at the end of an execution cycle to print any accumulated errors
    processPageErrors() {
        if (!this.errors) {
            this.errors = [];
        }
        this.errors.push(...this.pageErrors);

        if (this.errors?.length > 0) {
            this.processError(this.errors)
        }
    }


    /**
     * @param {*} financialInstitutions = array of Financial instituions value
     * Description - Method used to display financial institutions field on UI
     */
    setFIOptions(financialInstitutions = []) {
        /**
         * as part of plaid implementation once credentials got expired we are not getting that account details from 
         * api and if it is not present in DB but only in memory as a glam wrapper record then after creds expired it will
         * wipe out form grid without even noticing the user that there is such account with ur provider and to bring this
         * thing in notice of user we have to show error msg that this account needs refresh credentials as that account
         * financial institution present in combobox but its related account is not present in grid so we have to compare
         * grid financial instituion name and combobox values to find which account needs refresh creds. This is kind of 
         * generic thing for upcoming providers which has same limitation that we have in Plaid after credentials got expired.
         */
        let allFiINames = this.glamStore.getAllFinancialInstitutionsName();
        let uniqueFinancialInstitutions = [];
        let uniqueFinancialInstitutionIds = [];
        let finInstErrors = [];
        for (let i = 0; i < financialInstitutions.length; i++) {
            let targetFinInst= financialInstitutions[i];
            if (!uniqueFinancialInstitutionIds.includes(targetFinInst.id)) {
                uniqueFinancialInstitutions.push(targetFinInst);
                uniqueFinancialInstitutionIds.push(targetFinInst.id);
            }
            if (!allFiINames.includes(targetFinInst['name'])) {
                //first check for unsupported currencies
                if (this.bankToUnsupportedCurrencies[targetFinInst['id']]) {
                    if (!this.errors) {
                        this.errors = [];
                    }
                    let unsupportedCurrError = this.labels.UNSUPPORTED_CURRENCY_FOR_BANK.replace('BANK_NAME', targetFinInst['name']);
                    unsupportedCurrError = unsupportedCurrError.replace('CURRENCY_NAME', this.bankToUnsupportedCurrencies[targetFinInst['id']]);
                    finInstErrors.push(unsupportedCurrError);
                } else {
                    if (!this.errors) {
                        this.errors = [];
                    }
                    let connFailedError = this.labels.GLAMConnectionIssue.replace('xxxx', targetFinInst['name']);
                    finInstErrors.push(connFailedError);
                }
            }
        }
        // create finanical institution combobox here to display financial instituion names
        let financialInstitutionsList = this.createOptions(uniqueFinancialInstitutions, 'name', 'id');
        this.financialInstitutions = financialInstitutionsList;
        this.selectedFinancialInstitutionId = this.financialInstitutions[0];
        
        if (finInstErrors.length > 0) {
            if (this.errors) {this.errors = []}
            this.errors.push(...finInstErrors);
        }

        //For Plaid, set up connections (identities) to support multiple connections to the same bank
        //add only the connection values for the selected financial institution
        let connectionsForSelectedInstitution = this.filterIdentitiesForFinancialInstitution(Object.values(this.connectionIdentityMap), this.selectedFinancialInstitutionId.value);

        this.availableConnections = this.createOptions(connectionsForSelectedInstitution, 'identityName', 'id');
        this.selectedConnection = this.availableConnections[0].value;
    }

    initColumns() {
        let columns = Helper.getGLAMColumns();
        this.glamColumns = columns;  
        return columns;      
    }

    handleCellChange({ detail }) {
        switch (detail.colId) {
            case 'ledgerId':
                this.setLedger(detail);
                break;
            case 'glAccountId':
                this.setGLAccount(detail);
                break;
            case 'initialStartDate':
                this.setInitialStartDate(detail);
                break;
            default:
        }
    }

    setGLAccount({ value: glAccountId, rowId: id}) {
        const glam = this.glamStore.getItem(id);
        glam.glAccountId = glAccountId != null ? glAccountId.recordId : null;
        glam.glAccountName = glAccountId != null ? glAccountId.recordName : null;
        glam.glAccountCurrencyIsoCode = glAccountId != null ? glAccountId.currencyIsoCode : null;
        this.glamStore.updateItem(glam);        

        this.validateLedger(glam.ledgerId, glam, id, 'ledgerId');
        this.validateInitialStartDate(glam.initialStartDate, glam, id, 'initialStartDate');        

        this.glams = this.glamStore.getItems();
    }

    setIsDirtyStatus(status) {
        this.isDirty = status;
    }

    setLedger({ value: ledgerId, rowId: id, colId: columnId }) {
        this.clearErrors(id, columnId);
        const glam = this.glamStore.getItem(id);
        glam.ledgerId = ledgerId != null ? ledgerId.recordId : null;
        glam.ledgerName = ledgerId != null ? ledgerId.recordName : null;
        glam.ledgerCurrencyIsoCode = ledgerId != null ? ledgerId.currencyIsoCode : null;
        this.glamStore.updateItem(glam);
        this.validateLedger(ledgerId, glam, id, columnId);
        this.glams = this.glamStore.getItems();
    }

    setInitialStartDate({ value: initialStartDate, rowId: id, colId: columnId }) {
        this.clearErrors(id, columnId);
        const glam = this.glamStore.getItem(id);
        glam.initialStartDate = initialStartDate;            
        this.glamStore.updateItem(glam);
        this.validateInitialStartDate(initialStartDate, glam, id, columnId);
        this.glams = this.glamStore.getItems();
    }

    validateLedger(ledgerId, glam, id, columnId) {
        if (ledgerId == null && glam.glAccountId != null) {
            this.glamStore.addError(id, columnId, VALUE_REQUIRED);
        } else {
            this.clearErrors(id, columnId);         
        }
    }

    validateInitialStartDate(initialStartDate, glam, id, columnId) {
        var maxStartDate = glam.maxStartDate;
        if (initialStartDate == null && glam.glAccountId != null) {
            this.glamStore.addError(id, columnId, VALUE_REQUIRED);            
        } else if (initialStartDate >= maxStartDate) {
            const displayDate = Helper.formatDateToUTC(maxStartDate);
            this.glamStore.addError(id, columnId, START_DATE_TOO_GREAT + displayDate);
        } else {
            this.clearErrors(id, columnId);
        }
    }

    isDataGridValid() {
        if (this.glamStore.getItems() !== undefined && this.glamStore.getItems().length > 0) {
            return !(this.glamStore.getItems().find(item => item.errors.length > 0));
        }
            return true;
        }

    isFieldsValid() {
        const allValid = [...this.template.querySelectorAll('.validValue')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);
        return this.bypassValidation === false ? allValid : this.bypassValidation;
    }

    resetValidity() {
        [...this.template.querySelectorAll('.validValue')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.setCustomValidity('');
                inputCmp.reportValidity();
                return validSoFar;
            }, true);
        this.error = null;
        this.isError = false;       
    }

    

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        if (isError) {
            this.error = error;
            this.isError = isError;        
        } else {
            this.error = error.toString();
            this.isError = true;
        }
    }

    clearErrors(id, columnId) {
        this.glamStore.removeError(id, columnId);
        this.error = '';
    }
    
    showSpinner = isShown => {
        this.isSpinner = isShown;
    }

    stringifyEach = xs => xs.map(JSON.stringify);

    /**
     * 
     * @param {*} type - it will hold the type of navigation we want like standard__webpage/standard__navItemPage etc.....
     * @param {*} attributeObject - it will hold params for page like {url:'', c__state:''} etc......
     * Description - this method is used to dynamically navigate to other pages like record page or webpage based on type and attributeobject
     */
    openSitePage(type , attributeObject){ 
        this[NavigationMixin.Navigate]({
            type: type,
            attributes: attributeObject
        });
    }

    /**
     * Description - method will run and unsubscribe msgechannel when component is removed from DOM or destroyed
     */
    disconnectedCallback(){
        this.glamStore.unsubscribeMC();
    }

    /**
     * 
     * @param {*} data  - a message that needs to desplay in toast
     * @param {*} toastType -  variant of toast like Success:/Error:/Warning:/Info:
     * @param {*} toastArg - toast optional arguement and values will be success/error/warning/info
     */
    ShowToastMessg(msg, toastType, toastArg){
        NotificationService.displayToastMessage(this, msg, toastType, toastArg);
    }

}