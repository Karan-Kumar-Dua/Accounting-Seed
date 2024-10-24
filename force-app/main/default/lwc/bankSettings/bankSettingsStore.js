import {AbstractItemsStore} from 'c/utils';
import exchangeAccessToken from '@salesforce/apex/PlaidLinkHandler.exchangeAccessToken';
import { publish,subscribe,unsubscribe,createMessageContext,releaseMessageContext } from 'lightning/messageService';
import BDCChannel from "@salesforce/messageChannel/BDCChannel__c";
import Labels from './labels';

export default class bankSettingsStore extends AbstractItemsStore {

    pageToProviders = { 
        Yodlee: 'AcctSeed__FastLink', 
        Plaid: 'AcctSeed__PlaidLink'
     }; // used to store the providername with their vf page name

    subscription = null;
    context = createMessageContext();

    getCountryMappings(thisArg) {
        return [
            {label: thisArg.labels.INF_CANADA, value: 'CA'}, {label: thisArg.labels.INF_DENMARK, value: 'DK'}, 
            {label: thisArg.labels.INF_FRANCE, value: 'FR'}, {label: thisArg.labels.INF_GERMANY, value: 'DE'}, 
            {label: thisArg.labels.INF_IRELAND, value: 'IE'}, {label: thisArg.labels.INF_Netherlands, value: 'NL'},
            {label: thisArg.labels.INF_PORTUGAL, value: 'PT'}, {label: thisArg.labels.INF_SPAIN, value: 'ES'}, 
            {label: thisArg.labels.INF_SWEDEN, value: 'SE'}, {label: thisArg.labels.INF_USA, value: 'US'}
        ];
    }

    /**
     * Description: intend of this method to store constant value used for comparison and logical in JS to avoid hardcoding
     * @returns object of constant value
     */
    getConstantsValue(){
        let constants = {
            INF_YODLEE: Labels.INF_YODLEE,
            PLAID: Labels.INF_PLAID,
            REGISTER_MSG: Labels.INF_REGISTER_PROVIDER,
            DEREGISTER_MSG: Labels.INF_DEREGISTER_PROVIDER
        };
        return constants;
    }

    //hack to mark for update any GLAM records that don't have the ledger set (i.e. are using the legacy ledger)
    handleLegacyLedgers() {
        if (this.values) {
            this.values.map(item => {
                if (item.isLegacyLedger){
                    this.updateItem(item);
                }            
                return item;
            });
        }
    }

    getItem(itemId) {
        let item = this.values.find(value => value[this.idKey] === itemId);
        return { ...item };
    }

    /**
     * 
     * @param {*} selectedProvider - the provider which is currently selected from aggregation provider field 
     * @param {*} arrayOfProviders - all aggregation providers value present in aggragation prvider field
     * @returns - vf page link so that it can open in modal popup on click of new dynamically based on selected provider
     */
    getProviderFILink(selectedProvider, arrayOfProviders) {
        let pageLink = '/apex/';
        let providerValue = arrayOfProviders.find((item) => item.value === selectedProvider);
        return this.pageToProviders.hasOwnProperty(providerValue.value) ? pageLink + this.pageToProviders[providerValue.value] : undefined;
    }

    /**
     * 
     * @param {*} thisArg - this argumement of caller component
     * @param {*} compName - name of LWC component which attributes needs to be modified dynamically for (e.g. -> c-custom-lightbox)
     * @param {*} customProperties - array of object that contains properties for (e.g. -> [{attributeName = 'headerText' , value='abc'}])
     * Description - method used to customize the passed component for example remove header from popup in case of plaid 
     */
    customiseComponent(thisArg, compName, customProperties) {
        let componetDef = thisArg.template.querySelector('c-' + compName);
        if (customProperties) {
            this.customPropertiesComp(componetDef, customProperties);
        }
    }

    /**
     * 
     * @param {*} componetDef - LWC component definition after query to get access of its attributes and public properties
     * @param {*} customProperties   - array of object
     */
    customPropertiesComp(componetDef, customProperties) {
        customProperties.forEach(item => {
            componetDef[item.attributeName] = item.value;
        });
    }

    /**
     * 
     * @param {*} thisArg - this arguement from banksetting.js to access that JS methods and variables
     * @Description - this is used to subscribe message channel to get payload 
     */
    subscribeMC(thisArg) {
        if (this.subscription) {
            return;
        }
        this.subscription = subscribe(this.context, BDCChannel, (message) => {
            //if to make sure that there is method present that needs to be called
            /* and  calls are async like apex then handle in if and handle refresh after ur async 
               calls like exchangeToken()
            */
            if (message.payLoad.lwcMethodName && message.payLoad.asyncCalls) {
                // dynamically call LWC methods where methodname will be in string
                this[message.payLoad.lwcMethodName](message, thisArg);
            }
            // else when calls are not async 
            else if (message.payLoad.lwcMethodName) {
                this[message.payLoad.lwcMethodName](message, thisArg);
                // after any operation refresh the page
                thisArg.handleRefreshClick();
            }
            else {
                thisArg.handleRefreshClick();
            }
        });
    }

    /**
     * Description - used to unsubscribe when no longer needed or removed from DOM
     */
    unsubscribeMC() {
        unsubscribe(this.subscription);
        this.subscription = null;
        releaseMessageContext(this.context);
    }

    /**
     * 
     * @param {*} msgPayload - payload coming from PlaidLink vf page
     * @param {*} thisArg 
     * Description -  this method is used to convertaccessToken and stored in BDC_Access_Token custom setting
     */

    async exchangeToken(msgPayload, thisArg) {
        try {
            let apiMetadata = msgPayload.payLoad.metadata;
            if (apiMetadata && apiMetadata.public_token) {
                let accessToken = await exchangeAccessToken({ publicToken: apiMetadata.public_token, finId: apiMetadata.institution.institution_id});
                this.showToastMsg(msgPayload, thisArg);
            }
        } catch (err) {
            thisArg.processError(err);
        } finally {
            thisArg.handleRefreshClick();
        }
    }

    /**
     * 
     * @param {*} msgPayload -  the object that contains various keys and values
     * @param {*} thisArg -  this argument from banksetting.js
     */
    showToastMsg(msgPayload, thisArg){
        let toastType = msgPayload.payLoad.type;
        thisArg.ShowToastMessg(msgPayload.payLoad.message, toastType, toastType === 'Success:' ? 'success' : 'error');
    }
}