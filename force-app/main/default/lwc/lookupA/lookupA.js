import { LightningElement, track, api, wire } from 'lwc';
import apexSearchRecent from '@salesforce/apex/LookupHelper.searchRecent';
import apexSearch from '@salesforce/apex/LookupHelper.search';
import getSObjectValue from '@salesforce/apex/LookupHelper.fetchRecord';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import {CommonUtils, LabelService} from 'c/utils';
import Labels from './labels';

const DEFAULT_SEARCH_GROUP = 'ALL';
const DEFAULT_DISPLAY_FIELD = 'Name';
const DEFAULT_LIMIT = 5;
const DEFAULT_SEARCH_FILTER = {};
const MINIMAL_SEARCH_TERM_LENGTH = 2; // Min number of chars required to search
const SEARCH_DELAY = 300; // Wait 300 ms after user stops typing then, perform search
const REQUIRED_FIELD_MISSING_ERROR_MSG = LabelService.commonCompleteThisField;

export default class LookupA extends LightningElement {

    labels = {...LabelService, ...Labels};
    // query params
    @api searchObject;
    @api searchDisplayField;
    @api searchGroup;
    @api searchLimit;
    @api searchFilter;
    /* 
        The searchFilter is an object which will be converted into a SOSL Returning WHERE clause.

        A filter expression can be built with the help of keywords.
        Keywords can be imported into your module:
        `import { keywords } from 'c/lookupKeywords';`

        A basic filter expression follows the format:

        { 
            field: <FIELD_NAME>, 
            op:    <COMPARISON_OPERATOR>, 
            val:   <VALUE>, 
            type:  <DATA_TYPE> 
        }

        FIELD_NAME = (String) The name of any field on the `searchObject`
        COMPARISON_OPERATOR = (String) one of `keywords.op`. For example: `keywords.op.EQUAL`.
        VALUE = (ANY) The value being compared
        DATA_TYPE = (String) one of `keywords.type`. For example: `keywords.type.INTEGER`.

        Example - Integer:
        {
            field: 'NumberOfEmployees',
            op: keywords.op.GREATER_THAN,
            val: 15,
            type: keywords.op.INTEGER
        }

         => WHERE NumberOfEmployees > 15

        Example - List of String:
        {
            field: 'BillingState',
            op: keywords.op.IN,
            val: ['CA', 'TX', 'FL'],
            type: keywords.type.STRING
        }

        => WHERE BillingState IN ('CA', 'TX', 'FL')

        More complex expressions can be built using logical operators to combine basic expressions.
        Logical expressions follow the format:

        {
            <LOGICAL_OPERATOR>: [
                <BASIC_EXPRESSION>,
                <BASIC_EXPRESSION>
            ]
        }

        LOGICAL_OPERATOR = (String) one of `keywords.logical`. For example: `keywords.logical.or`.

        Example - OR:
        {
            keywords.logical.OR: [
                { field: 'NumberOfEmployees', op: keywords.op.GREATER_THAN, val: 15, type: keywords.op.INTEGER },
                { field: 'BillingState', op: keywords.op.IN, val: ['CA', 'TX', 'FL'], type: keywords.type.STRING }
            ]
        }

        => WHERE (NumberOfEmployees > 15 OR  BillingState IN ('CA', 'TX', 'FL'))

         Example - Nested OR/AND:
        {
            keywords.logical.OR: [
                { field: 'NumberOfEmployees', op: keywords.op.GREATER_THAN, val: 15, type: keywords.op.INTEGER },
                keywords.logical.AND: [
                    { field: 'BillingState', op: keywords.op.IN, val: ['CA', 'TX', 'FL'], type: keywords.type.STRING },
                    { field: 'BillingCity', op: keywords.op.NOT_IN, val: ['Los Angeles', 'Miami', 'Austin'] }
                ]
            ]
        }

        => WHERE (NumberOfEmployees > 15 OR  (BillingState IN ('CA', 'TX', 'FL') AND BillingCity NOT IN ('Los Angeles', 'Miami', 'Austin')))

    */

    // additional display data
    @api label;
    @api selection = [];
    @api placeholder = '';
    @api errors = [];
    @api scrollAfterNItems;
    @api customKey;
    @api hideSelectionIcon;
    @api initValue;
    @api required;
    @api fieldLevelHelp;
    @api disabled;
    @api retrieveFields;
    @api showTooltip = false;

    @api messages = {
        requiredFieldMissingMessage: REQUIRED_FIELD_MISSING_ERROR_MSG
    };

    @track searchTerm = '';
    @track searchResults = [];
    @track hasFocus = false;
    @track showSpinner = false;

    cleanSearchTerm;
    blurTimeout;
    searchThrottlingTimeout;

    get _searchDisplayField() {
        return this.searchDisplayField || DEFAULT_DISPLAY_FIELD;
    }
    get _searchGroup() {
        return this.searchGroup || DEFAULT_SEARCH_GROUP;
    }
    get _searchLimit() {
        return this.searchLimit || DEFAULT_LIMIT;
    }
    get _searchFilter() {
        return this.searchFilter || DEFAULT_SEARCH_FILTER;
    }

    get showFieldLevelHelp() {
        return !!this.fieldLevelHelp;
    }

    get isShowRecentRow() {
        return this.searchResults && this.searchResults.length && this.cleanSearchTerm.length < MINIMAL_SEARCH_TERM_LENGTH;
    }

    get recentRecordsLabel() {
        return `Recent ${this.sobjectLabelPlural || 'Records'}`;
    }

    setResultValue(result) {
        try {
            this.selection = [{
                id: this.initValue,
                title: result.obj.Name,
                icon: this.sobjectIconName || result.icon,
                ...result.obj
            }];
            this.dispatchEvent(new CustomEvent('initvalueloaded', {
                detail: {
                    recordId: this.currentRecordIdCursor,
                    id: this.initValue,
                    recordName: this.selection[0].title,
                    currencyIsoCode: this.selection[0].currencyIsoCode,
                    ...this.prepareRetrieveFieldsData(this.selection[0])
                }
            }));
        } catch(e) {}
    }

// EXPOSED FUNCTIONS

    @api
    setSearchResults(results = []) {
        this.searchResults = results.map(result => {
            return {
                id: result.obj.Id,
                title: result.obj[this._searchDisplayField],
                subtitle: result.label,
                icon: this.sobjectIconName || result.icon || 'standard:account',
                currencyIsoCode: result.obj.CurrencyIsoCode,
                ...this.prepareRetrieveFieldsData(result.obj)
            };
        });
        this.resetItemsClasses();
        if (this.searchResults.length > 0) {
            this.dispatchEvent(new CustomEvent('open'));
        }
    }

    @api
    getSelection() {
        return this.selection;
    }

    @api
    getKey() {
        return this.customKey;
    }

    @api
    focus() {
        const input = this.template.querySelector('input');
        input && input.focus();
    }

    @api
    reportValidity() {
        this.required && (
            this.errors = this.selection.length &&
                this.errors.filter(item => item.message !== (this.messages && this.messages.requiredFieldMissingMessage || REQUIRED_FIELD_MISSING_ERROR_MSG)) ||
                (
                    !this.errors.find(item => item.message === (this.messages && this.messages.requiredFieldMissingMessage || REQUIRED_FIELD_MISSING_ERROR_MSG)) &&
                        this.errors.push({message: (this.messages && this.messages.requiredFieldMissingMessage || REQUIRED_FIELD_MISSING_ERROR_MSG)}),
                    this.errors
                )
        );
        return !this.errors.length;
    }

    /**
     * Set a custom error message, similar to a lightning-input.
     * @param {String} err Custom error message
     */
    @api
    setCustomValidity (err) {
        this.errors = [ { message: err } ];
    }

    @api
    cleanErrors() {
        this.errors = [];
    }

    @wire(getObjectInfo, { objectApiName: '$searchObject' })
    fetchSObjectInfo(result) {
        if (result.data) {
            const sobject = result.data;
            this.sobjectLabelPlural = sobject.labelPlural;

            let iconUrlName = sobject.themeInfo && sobject.themeInfo.iconUrl && sobject.themeInfo.iconUrl.split('/').reverse()[0];
            if (iconUrlName) {
                iconUrlName = iconUrlName.substring(0, iconUrlName.indexOf('_'));
                this.sobjectIconName = `${sobject.custom && 'custom' || 'standard'}:${iconUrlName}`;
            }

            if (this.initValue != null && this.searchObject != null) {
                getSObjectValue({objApiName: this.searchObject, objId: this.initValue, retrieveFields: this.retrieveFields})
                    .then(result => this.setResultValue(result));
            }
        }
    }

// INTERNAL FUNCTIONS
    prepareRetrieveFieldsData(origin) {
        let result = {};
        this.retrieveFields && Object.entries(this.retrieveFields).forEach(entry => {
            const [objectApiName, fieldApiNames] = entry;
            fieldApiNames.forEach(fieldApiName => {
                const fieldApiNameParts = fieldApiName.split('.');
                result[fieldApiName] = origin[fieldApiName] || (fieldApiNameParts.length === 2 ?
                        (origin[fieldApiNameParts[0]] && origin[fieldApiNameParts[0]][fieldApiNameParts[1]]) : origin[fieldApiName]);
            })
        });
        return result;
    }

    @api
    changeInitValue(currentRecordId){
        if(currentRecordId){
            getSObjectValue({objApiName: this.searchObject, objId: currentRecordId, retrieveFields: this.retrieveFields})
                        .then(result => this.setResultValue(result));
        }else{
            this.selection = [];
        }
    }

    updateSearchTerm(newSearchTerm, isForceRetrieve = false) {
        this.searchTerm = newSearchTerm;

        // Compare clean new search term with current one and abort if identical
        const newCleanSearchTerm = newSearchTerm.trim().replace(/\*/g, '').toLowerCase();
        if (this.cleanSearchTerm === newCleanSearchTerm && !isForceRetrieve) {
            return;
        }

        this.hasFocus = true;

        // Save clean search term
        this.cleanSearchTerm = newCleanSearchTerm;

        // Apply search throttling (prevents search if user is still typing)
        if (this.searchThrottlingTimeout) {
            clearTimeout(this.searchThrottlingTimeout);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchThrottlingTimeout = setTimeout(() => {
                // Send search event if search term is long enougth
                let requestParams = {};
                requestParams.searchOptionsJson = JSON.stringify({
                    queryTerm: this.cleanSearchTerm,
                    searchTerm: this.cleanSearchTerm,
                    searchGroup: this._searchGroup,
                    searchObject: this.searchObject,
                    searchDisplayField: this._searchDisplayField,
                    searchLimit: this._searchLimit,
                    retrieveFields: this.retrieveFields
                });
                requestParams.searchFilterJson = JSON.stringify(this._searchFilter);
                this.showSpinner = true;
                (this.cleanSearchTerm.length >= MINIMAL_SEARCH_TERM_LENGTH ?
                    apexSearch(requestParams) : apexSearchRecent(requestParams))
                        .then(response => {
                            if (response) {
                                this.setSearchResults(response);
                            }
                        })
                        .catch(error => {
                            //this.errors = [error];
                        })
                        .finally(() => {this.showSpinner = false});

                this.searchThrottlingTimeout = null;
            },
            SEARCH_DELAY
        );
    }

    isSelectionAllowed() {
        return !this.hasSelection();
    }

    hasResults() {
        return this.searchResults.length > 0;
    }

    hasSelection() {
        return this.selection.length > 0;
    }

    resetItemsClasses() {
        this.searchResults = this.searchResults.map(item => ({
            ...item,
            classes: CommonUtils.computeClasses([item.id === this.currentRecordIdCursor && 'itemOnHover', 'slds-media', 'slds-listbox__option', 'slds-listbox__option_entity', 'slds-listbox__option_has-meta'])
        }));
    }


// EVENT HANDLING

    handleMouseenter(event) {
        this.currentRecordIdCursor = event.currentTarget.dataset.recordid;
        this.resetItemsClasses();
    }

    handleKeydown(event) {
        const recordIdCursorIndex = this.searchResults.findIndex(item => item.id === this.currentRecordIdCursor);
        switch (event.key) {
            case "Down": // IE/Edge specific value
            case "ArrowDown":
                if (!this.selection || !this.selection.length) {
                    const nextRecordIdCursorIndex = (this.hasFocus && ~recordIdCursorIndex && ((recordIdCursorIndex + 1) % this.searchResults.length)) || 0;
                    this.currentRecordIdCursor = this.searchResults[nextRecordIdCursorIndex] && this.searchResults[nextRecordIdCursorIndex].id;
                    this.resetItemsClasses();
                    this.hasFocus = true;
                }
                break;
            case "Up": // IE/Edge specific value
            case "ArrowUp":
                if (!this.selection || !this.selection.length) {
                    let prevRecordIdCursorIndex = this.searchResults.length - 1;
                    if (this.hasFocus && ~recordIdCursorIndex) {
                        prevRecordIdCursorIndex = !recordIdCursorIndex ? (this.searchResults.length - 1) : (recordIdCursorIndex - 1);
                    }
                    this.currentRecordIdCursor = this.searchResults[prevRecordIdCursorIndex] && this.searchResults[prevRecordIdCursorIndex].id;
                    this.resetItemsClasses();
                    this.hasFocus = true;
                }
                break;
            case "Enter":
                if (this.hasFocus) {
                    const selectedItems = this.searchResults.filter(item => item.id === this.currentRecordIdCursor);
                    if (selectedItems.length) {
                        this.selection = [...this.selection, ...selectedItems];
                        this.dispatchEvent(new CustomEvent('selectionchange', {
                            detail: {
                                recordId: this.currentRecordIdCursor,
                                recordName: selectedItems[0].title,
                                currencyIsoCode: selectedItems[0].currencyIsoCode,
                                ...this.prepareRetrieveFieldsData(this.selection[0])
                            }
                        }));
                    }
                    this.hasFocus = false;
                } else if (!this.selection || !this.selection.length) {
                    this.hasFocus = true;
                    if (!this.searchResults || !this.searchResults.length) {
                        this.updateSearchTerm('', true);
                    }
                }
                break;
            case "Backspace":
                if (!this.hasFocus && this.selection.length) {
                    this.selection = [];
                    this.cleanSearchTerm = '';
                    this.searchTerm = '';
                    // Notify parent components that selection has changed
                    this.dispatchEvent(new CustomEvent('selectionchange'));
                }
                break;
            case "Esc": // IE/Edge specific value
            case "Escape":
                this.hasFocus = false;
                this.currentRecordIdCursor = null;
                break;
        }
    }

    handleInput(event) {
        // Prevent action if selection is not allowed
        if (!this.isSelectionAllowed()) {
            return;
        }
        this.updateSearchTerm(event.target.value);
    }

    handleResultClick(event) {
        const recordId = event.currentTarget.dataset.recordid;
        const recordName = event.currentTarget.dataset.recordname;
        const currencyIsoCode = event.currentTarget.dataset.currencyisocode;
        // Save selection
        let selectedItem = this.searchResults.filter(result => result.id === recordId);
        if (selectedItem.length === 0) {
            return;
        }
        selectedItem = selectedItem[0];
        const newSelection = [...this.selection];
        newSelection.push(selectedItem);
        this.selection = newSelection;

        // Reset search
        if (this.searchTerm) {
            this.searchTerm = '';
            this.searchResults = [];
        }

        // Notify parent components that selection has changed
        this.dispatchEvent(new CustomEvent('selectionchange', { detail: {
            recordId : recordId,
            recordName: recordName,
            currencyIsoCode: currencyIsoCode,
            ...this.prepareRetrieveFieldsData(this.selection[0])
        }}));
    }

    handleComboboxClick() {
        // Hide combobox immediatly
        if (this.blurTimeout) {
            window.clearTimeout(this.blurTimeout);
        }
        this.hasFocus = false;
    }

    handleFocus(event) {
        // Prevent action if selection is not allowed
        if (!this.isSelectionAllowed()) {
            return;
        }
        this.updateSearchTerm(event.target.value);
        this.hasFocus = true;
    }

    handleBlur() {
        // Prevent action if selection is not allowed
        if (!this.isSelectionAllowed()) {
            return;
        }
        // Delay hiding combobox so that we can capture selected result
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.blurTimeout = window.setTimeout(() => {
                this.hasFocus = false;
                this.blurTimeout = null;
            },
            300
        );
    }

    handleRemoveSelectedItem(event) {
        const recordId = event.currentTarget.name;
        this.selection = this.selection.filter(item => item.id !== recordId);
        // Notify parent components that selection has changed
        this.dispatchEvent(new CustomEvent('selectionchange'));
    }

    handleClearSelection() {
        this.selection = [];
        // Notify parent components that selection has changed
        this.dispatchEvent(new CustomEvent('selectionchange'));
    }
    showToolTip(event){
        if(this.showTooltip) {
            this.template.querySelectorAll('.tooltip').forEach(item =>{
            if(item.title === event.currentTarget.dataset.name){ 
                item.className = 'tooltip slds-slide-from-top-to-bottom slds-popover slds-popover_tooltip slds-nubbin_bottom-left slds-slide-from-right-to-left slds-rise-from-ground';
            }
         });
        }  
    }
       
    hideToolTip(){
        if(this.showTooltip) {
            this.template.querySelectorAll('.tooltip').forEach(item =>{
                item.className = 'tooltip slds-popover slds-popover_tooltip slds-nubbin_bottom-left slds-slide-from-right-to-left slds-fall-into-ground';
            });
        } 
    }
        
        


// STYLE EXPRESSIONS

    get getContainerClass() {
        let css = 'slds-combobox_container slds-has-inline-listbox ';
        if (this.hasFocus && this.hasResults()) {
            css += 'slds-has-input-focus ';
        }
        if (this.errors.length > 0) {
            css += 'has-custom-error';
        }
        return css;
    }

    get getDropdownClass() {
        let css = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ';
        if (this.hasFocus && this.hasResults()) {
            css += 'slds-is-open';
        } else {
            css += 'slds-combobox-lookup';
        }
        return css;
    }

    get getInputClass() {
        let css = 'slds-input slds-combobox__input has-custom-height ' + (this.errors.length === 0 ? '' : 'has-custom-error ');
        css += 'slds-combobox__input-value ' + (this.hasSelection() ? 'has-custom-border' : '');
        return css;
    }

    get getComboboxClass() {
        let css = 'slds-combobox__form-element slds-input-has-icon ';
        css += (this.hasSelection() && !this.hideSelectionIcon ? 'slds-input-has-icon_left-right' : 'slds-input-has-icon_right');
        return css;
    }

    get getSearchIconClass() {
        return'slds-input__icon slds-input__icon_right ' + (this.hasSelection() ? 'slds-hide' : '');
    }

    get getClearSelectionButtonClass() {
        return 'slds-button slds-button_icon slds-input__icon slds-input__icon_right '
            + (this.hasSelection() ? '' : 'slds-hide');
    }

    get getSelectIconName() {
        return this.hasSelection() ? this.selection[0].icon : 'standard:default';
    }

    get getSelectIconClass() {
        return 'slds-combobox__input-entity-icon '
            + (this.hasSelection() && !this.hideSelectionIcon ? '' : 'slds-hide');
    }

    get getInputValue() {
        return this.hasSelection() ? this.selection[0].title : this.searchTerm;
    }

    get getListboxClass() {
        return 'slds-listbox slds-listbox_vertical slds-dropdown slds-dropdown_fluid '
            + (this.scrollAfterNItems ? 'slds-dropdown_length-with-icon-' + this.scrollAfterNItems : '');
    }

    get isInputReadonly() {
        return this.hasSelection();
    }

    get isExpanded() {
        return this.hasResults();
    }

    get showLabel() {
        return this.label;
    }

    get toolTipClass() { 
        return this.showTooltip ? 'slds-listbox__item tooltip-holder' : 'slds-listbox__item';
      }
}