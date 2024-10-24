import {api, LightningElement, track, wire} from 'lwc';
import {Account, AccountingSettings, Address, Billing} from 'c/sobject';
import {getRecord, getFieldValue, updateRecord} from 'lightning/uiRecordApi';
import fetchConfig from '@salesforce/apex/AddressValidationHelper.fetchConfig';
import pingAvaTax from '@salesforce/apex/AccountingSettingsHelper.pingAvaTax';
import invokeValidate from '@salesforce/apex/AddressValidationHelper.validate';
import invokePreCheck from '@salesforce/apex/AddressValidationHelper.precheck';
import {NotificationService, CommonUtils, LabelService, ErrorUtils} from "c/utils";
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import Labels from './labels';
const NEED_VALIDATE_STATE = {id: 'needValidate'};
const REPLACE_VALID_ADDR_STATE = {id: 'replaceValidAddr'};

const fieldsBySObjectApiNames = {
    [Account.objectApiName]: {
        billing: {street: Account.bStreet, city: Account.bCity, state: Account.bState, postalCode: Account.bPostalCode, country: Account.bCountry},
        shipping: {street: Account.sStreet, city: Account.sCity, state: Account.sState, postalCode: Account.sPostalCode, country: Account.sCountry}
    },
    [AccountingSettings.objectApiName]: {
        billing: {
            street: AccountingSettings.street, city: AccountingSettings.city, state: AccountingSettings.region,
            postalCode: AccountingSettings.postalCode, country: AccountingSettings.countryCode
        }
    },
    [Address.objectApiName]: {
        billing: {
            street: Address.street, city: Address.city, state: Address.state,
            postalCode: Address.postalCode, country: Address.countryCode
        }
    },
    [Billing.objectApiName]: {
        billing: {street: Billing.bStreet, city: Billing.bCity, state: Billing.bState, postalCode: Billing.bPostalCode, country: Billing.bCountry},
        shipping: {street: Billing.sStreet, city: Billing.sCity, state: Billing.sState, postalCode: Billing.sPostalCode, country: Billing.sCountry}
    }
}

const SHIPPING_ADDRESS = [
    {
        key: 'street',
        origin: {
            label: Labels.INF_SHIPPING_STREET
        },
        validated: {
            label: Labels.INF_VALIDATED_SHIPPING_STREET
        }
    },
    {
        key: 'city',
        origin: {
            label: Labels.INF_SHIPPING_CITY
        },
        validated: {
            label: Labels.INF_VALIDATED_SHIPPING_CITY
        }
    },
    {
        key: 'state',
        origin: {
            label: Labels.INF_SHIPPING_STATE
        },
        validated: {
            label: Labels.INF_VALIDATED_SHIPPING_STATE
        }
    },
    {
        key: 'postalCode',
        origin: {
            label: Labels.INF_SHIPPING_POSTAL_CODE
        },
        validated: {
            label: Labels.INF_VALIDATED_SHIPPING_POSTAL_CODE
        }
    },
    {
        key: 'country',
        origin: {
            label: Labels.INF_SHIPPING_COUNTRY
        },
        validated: {
            label: Labels.INF_VALIDATED_SHIPPING_COUNTRY
        }
    }
];

const BILLING_ADDRESS = [
    {
        key: 'street',
        origin: {
            label: Labels.INF_BILLING_STREET
        },
        validated: {
            label: Labels.INF_VALIDATED_BILLING_STREET
        }
    },
    {
        key: 'city',
        origin: {
            label: Labels.INF_BILLING_CITY
        },
        validated: {
            label: Labels.INF_VALIDATED_BILLING_CITY
        }
    },
    {
        key: 'state',
        origin: {
            label: Labels.INF_BILLING_STATE
        },
        validated: {
            label: Labels.INF_VALIDATED_BILLING_STATE
        }
    },
    {
        key: 'postalCode',
        origin: {
            label: Labels.INF_BILLING_POSTAL_CODE
        },
        validated: {
            label: Labels.INF_VALIDATED_BILLING_POSTAL_CODE
        }
    },
    {
        key: 'country',
        origin: {
            label: Labels.INF_BILLING_COUNTRY
        },
        validated: {
            label: Labels.INF_VALIDATED_BILLING_COUNTRY
        }
    }
];

const themesBySeverities = {
    'CONFIRM': 'slds-theme_success',
    'INFO': 'slds-theme_info',
    'WARN': 'slds-theme_warning',
    'ERROR': 'slds-theme_error',
    'FATAL': 'slds-theme_error'
};


export default class AddressValidator extends LightningElement {
    labels = {...Labels, ...LabelService};
    @api recordId;
    @api sObjectName;
    @api licenseLinkedId;
    @api isHideBackdrop = false;
    @api isAutoOpen = false;

    @track errorMessage;
    @track currentState = {
        ...NEED_VALIDATE_STATE,
        shipping: {
            isCheckedNotPassed: false,
            isValidated: false,
            messages: []
        },
        billing: {
            isCheckedNotPassed: false,
            isValidated: false,
            messages: []
        }
    };

    showSpinner = true;
    fields;
    avalaraLicenseErrors = [LabelService.avalaraLicenseDoesNotExistMessage];

    @track shippingAddress = [...SHIPPING_ADDRESS];
    @track billingAddress = [...BILLING_ADDRESS];
    @track avaTaxLicenses;

    constructor() {
        super();
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            //at this time, recordId is not passed by default for quick actions. If null, retrieve from page
            if (!this.recordId) {
                this.recordId = currentPageReference.state.recordId;
            }
            //At the time of writing, the objectApiName is null for page Refs for Object Quick Actions. (probably a SF bug.)
            //thus, as an workaround, the object api name is parsed from the front of quick action button's api name when the apiName in the state is null
            //if the component is added to context where the objectApiName is passed, consider using that value to set the sObjectName here
            if (!this.sObjectName) {
                if (!currentPageReference.state.objectApiName) {
                    let apiString = currentPageReference.attributes.apiName;
                    //if the api string has a dot, take the prefix which for quick action buttons is the object name
                    this.sObjectName = apiString.substring(0, apiString.indexOf("."));
                } else {
                    this.sObjectName = currentPageReference.state.objectApiName;
                }
            }
        }
    }

    @api openModal() {
        const addressValidatorModal = this.template.querySelector('c-modal-popup-base[data-id="addressValidatorModal"]');
        addressValidatorModal && addressValidatorModal.openModal();
    }

    @api closeModal() {
        const addressValidatorModal = this.template.querySelector('c-modal-popup-base[data-id="addressValidatorModal"]');
        addressValidatorModal && addressValidatorModal.closeModal();
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$fields'
    })
    fetchCommonRecord({data, error}) {
        if (data) {
            this.showSpinner = false;
            if (this.isBillingAddress) {
                this.billingAddress = this.billingAddress.map(item => ({
                    ...item, origin: {...item.origin, value: getFieldValue(data, fieldsBySObjectApiNames[this.sObjectName]['billing'][item.key])}
                }));
            }
            if (this.isShippingAddress) {
                this.shippingAddress = this.shippingAddress.map(item => ({
                    ...item, origin: {...item.origin, value: getFieldValue(data, fieldsBySObjectApiNames[this.sObjectName]['shipping'][item.key])}
                }));
            }
            this.check();
        }
    }

    get isShippingAddress() {
        return new Set([Account.objectApiName, Billing.objectApiName]).has(this.sObjectName);
    }

    get isBillingAddress() {
        return new Set([Account.objectApiName, AccountingSettings.objectApiName, Address.objectApiName, Billing.objectApiName]).has(this.sObjectName);
    }

    get isNeedValidateState() {
        return this.currentState.id === NEED_VALIDATE_STATE.id;
    }

    get isReplaceValidAddrState() {
        return this.currentState.id === REPLACE_VALID_ADDR_STATE.id;
    }

    get isShowMiddleSeparator() {
        return this.isShippingAddress && this.isBillingAddress;
    }

    get isValidatedBtnDisabled() {
        return this.showSpinner || this.currentState.billing.isCheckedNotPassed || this.currentState.shipping.isCheckedNotPassed ||
            (this.isAccountSobjectType && this.isAvalaraLicenseErrors);
    }

    get isReplaceAddressBtnDisabled() {
        return this.showSpinner || (!this.currentState.billing.isValidated && !this.currentState.shipping.isValidated);
    }

    get isAccountSobjectType() {
        return this.sObjectName === Account.objectApiName;
    }

    get isAvalaraLicenseErrors() {
        return !this.avaTaxLicenses || !this.avaTaxLicenses.length;
    }

    get avalaraLicenseValue() {
        return this.avaTaxLicenses && this.avaTaxLicenses[0] && this.avaTaxLicenses[0].value;
    }

    connectedCallback() {
        this.isAccountSobjectType && this.retrieveConfig();

        let fields = [];
        Object.values(fieldsBySObjectApiNames[this.sObjectName]).forEach(row => {
            fields = [...fields, ...Object.values(row)];
        })
        this.fields = fields;
    }

    retrieveConfig() {
        fetchConfig()
            .then((result) => {
                this.avaTaxLicenses = result && result.avaTaxLicenses.map(avaTaxLicense => ({label: avaTaxLicense.Name, value: avaTaxLicense.Id}));
            })
            .catch(e => console.log(e));
    }

    queryAvalaraLicense() {
        return this.template.querySelector('[data-id="lightningCombobox-avalaraLicense"]');
    }

    closeQuickAction(detail = {isNeedRefresh: false}) {
        let aCustomCloseEvent = new CustomEvent('closequickaction', {detail});
        //was trying to call these conditionally based on if a custom event was defined
        //but couldn't find the correct attribute to test so ended up calling both
        this.dispatchEvent(aCustomCloseEvent);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    preValidate() {
        if (this.isAccountSobjectType) {
            this.showSpinner = true;
            pingAvaTax({licenseId: this.queryAvalaraLicense()?.value})
                .then((res) => {
                    if (res.authenticated) {
                        this.validate();
                    } else {
                        NotificationService.displayToastMessage(
                            this,
                            Labels.ERR_NOT_AUTHENTICATE_ACCOUNT_AVALARA_SERVICE,
                            LabelService.commonToastErrorTitle,
                            'error'
                        )
                    }
                })
                .catch((err) => {
                    const {error} = ErrorUtils.processError(err);
                    NotificationService.displayToastMessage( this, error, LabelService.commonToastErrorTitle, 'error' );
                })
                .finally(() => {this.showSpinner = false});
        } else {
            this.validate();
        }
    }

    validate() {
        let validatePromises = [];

        this.isBillingAddress && validatePromises.push(this.validatePromise('billingAddress', 'billing'));
        this.isShippingAddress && validatePromises.push(this.validatePromise('shippingAddress', 'shipping'));

        this.showSpinner = true;
        Promise.all(validatePromises)
            .then(() => {this.currentState = {...this.currentState, ...REPLACE_VALID_ADDR_STATE}})
            .finally(() => {this.showSpinner = false});
    }

    validatePromise(addressKey, stateKey) {
        const licenseLinkedId = this.licenseLinkedId || this.recordId;
        const avaTaxLicenseId = this.queryAvalaraLicense()?.value;
        const params = this[addressKey].map(item => ({ [item.key]: item.origin.value }));
        return invokeValidate(Object.assign({ licenseLinkedId, avaTaxLicenseId }, ...params))
            .then(result => {
                if (result.messages.length) {
                    this.currentState[stateKey].isValidated = false;
                    this.currentState[stateKey].messages = result.messages;
                } else if (result.address) {
                    this[addressKey] = this[addressKey].map(item => ({
                        ...item, validated: {...item.validated, value: result.address[item.key]}
                    }));

                    this.currentState[stateKey].isValidated = true;
                    this.currentState[stateKey].messages = [{message: LabelService.commonValidated, severity: 'CONFIRM'}];
                }
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            })
            .finally(() => {
                this.currentState[stateKey].messages =
                    this.currentState[stateKey].messages.map(
                        item => ({
                            ...item,
                            classes: CommonUtils.computeClasses([
                                'slds-box', 'validation-status-holder-box', themesBySeverities[item.severity]
                            ])
                        })
                    )
            });
    }

    prepareAddress4Update(addressKey, stateKey) {
        let fields = {};
        const fieldsByKeys = fieldsBySObjectApiNames[this.sObjectName][stateKey];
        this[addressKey].forEach(item => {
            const fieldApiName = fieldsByKeys[item.key].fieldApiName;
            fields[fieldApiName] = item.validated.value;
        });

        return fields;
    }

    replaceWithValidatedAddress() {
        let fields = {'Id': this.recordId};

        this.isShippingAddress &&
            (fields = {...fields, ...this.prepareAddress4Update('shippingAddress', 'shipping')});
        this.isBillingAddress &&
            (fields = {...fields, ...this.prepareAddress4Update('billingAddress', 'billing')});

        const recordInput = { fields };
        this.showSpinner = true;
        updateRecord(recordInput)
            .then(() => {
                NotificationService.displayToastMessage(
                    this,
                    Labels.INF_SUCCESSFULLY_UPDATED
                );

                this.closeQuickAction({isNeedRefresh: true});
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            })
            .finally(() => {this.showSpinner = false});
    }

    handleConnected() {
        this.isAutoOpen && this.openModal();
    }

    check() {
        let validatePromises = [];

        this.isBillingAddress && validatePromises.push(this.preCheckPromise('billingAddress', 'billing'));
        this.isShippingAddress && validatePromises.push(this.preCheckPromise('shippingAddress', 'shipping'));

        this.showSpinner = true;
        Promise.all(validatePromises)
            .then(() => {this.currentState = {...this.currentState, ...NEED_VALIDATE_STATE}})
            .finally(() => {this.showSpinner = false});
    }

    preCheckPromise(addressKey, stateKey) {
        const params = this[addressKey].map(item => ({ [item.key]: item.origin.value }));
        return invokePreCheck(Object.assign({}, ...params))
            .then(result => {
                if (result.messages.length) {
                    const pageErrorMessage = result.messages.find(message => message.errorLevel === 'PAGE');
                    if (pageErrorMessage) {
                        this.errorMessage = pageErrorMessage.message;
                    } else {
                        this.currentState[stateKey].isCheckedNotPassed = true;
                        this.currentState[stateKey].messages = result.messages;
                    }
                }
            })
            .catch(error => {
                NotificationService.displayToastMessage(
                    this,
                    error.body.message,
                    `${LabelService.commonToastErrorTitle}:`,
                    'error'
                );
            })
            .finally(() => {
                this.currentState[stateKey].messages =
                    this.currentState[stateKey].messages.map(item => ({...item, classes: CommonUtils.computeClasses(['slds-box', 'validation-status-holder-box', themesBySeverities[item.severity]])}))
            });
    }
}