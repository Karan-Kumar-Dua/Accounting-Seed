import { LightningElement, track, api } from 'lwc';
import apexSearch from '@salesforce/apex/LookupHelper.search';
import getSObjectValue from '@salesforce/apex/LookupHelper.getSObjectValue';
import {LabelService} from 'c/utils';
import Labels from './labels';

const DEFAULT_SEARCH_GROUP = 'ALL';
const DEFAULT_DISPLAY_FIELD = 'Name';
const DEFAULT_LIMIT = 5;
const DEFAULT_SEARCH_FILTER = {};
const MINIMAL_SEARCH_TERM_LENGTH = 2; // Min number of chars required to search
const SEARCH_DELAY = 300; // Wait 300 ms after user stops typing then, perform search
const REQUIRED_FIELD_MISSING_ERROR_MSG = LabelService.COMMON_ERR_COMPLETE_THIS_FIELD;

export default class Lookup extends LightningElement {

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

    @track searchTerm = '';
    @track searchResults = [];
    @track hasFocus = false;

    cleanSearchTerm;
    blurTimeout;
    searchThrottlingTimeout;
    setDefaultValue = false;

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

    renderedCallback() {
        if (!this.setDefaultValue && this.initValue != null && this.searchObject != null) {
            getSObjectValue({objApiName: this.searchObject, objId: this.initValue})
              .then(result => this.setResultValue(result))
              .then(() => (this.setDefaultValue = true));
        }
    }

    setResultValue(result) {
        try {
            this.selection = [{
                id: this.initValue,
                title: result.obj.Name,
                icon: result.icon
            }];
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
                icon: result.icon || 'standard:account',
                currencyIsoCode: result.obj.CurrencyIsoCode
            };
        });
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
                this.errors.filter(item => item.message != REQUIRED_FIELD_MISSING_ERROR_MSG) ||
                (this.errors.push({message: REQUIRED_FIELD_MISSING_ERROR_MSG}), this.errors)
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

// INTERNAL FUNCTIONS

    updateSearchTerm(newSearchTerm) {
        this.searchTerm = newSearchTerm;

        // Compare clean new search term with current one and abort if identical
        const newCleanSearchTerm = newSearchTerm.trim().replace(/\*/g, '').toLowerCase();
        if (this.cleanSearchTerm === newCleanSearchTerm) {
            return;
        }

        // Save clean search term
        this.cleanSearchTerm = newCleanSearchTerm;

        // Ignore search terms that are too small
        if (newCleanSearchTerm.length < MINIMAL_SEARCH_TERM_LENGTH) {
            this.searchResults = [];
            return;
        }

        // Apply search throttling (prevents search if user is still typing)
        if (this.searchThrottlingTimeout) {
            clearTimeout(this.searchThrottlingTimeout);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchThrottlingTimeout = setTimeout(() => {
                // Send search event if search term is long enougth
                if (this.cleanSearchTerm.length >= MINIMAL_SEARCH_TERM_LENGTH) {
                    let requestParams = {};
                    requestParams.searchOptionsJson = JSON.stringify({
                        searchTerm: this.cleanSearchTerm,
                        searchGroup: this._searchGroup,
                        searchObject: this.searchObject,
                        searchDisplayField: this._searchDisplayField,
                        searchLimit: this._searchLimit
                    });
                    requestParams.searchFilterJson = JSON.stringify(this._searchFilter);
                    apexSearch(requestParams)
                    .then(response => {
                        if (response) {
                            this.setSearchResults(response);
                        }
                    })
                    .catch(error => {
                        //this.errors = [error];
                    });
                }
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


// EVENT HANDLING

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
        this.searchTerm = '';
        this.searchResults = [];

        // Notify parent components that selection has changed
        this.dispatchEvent(new CustomEvent('selectionchange', { detail: {recordId : recordId, recordName: recordName, currencyIsoCode: currencyIsoCode}}));
    }

    handleComboboxClick() {
        // Hide combobox immediatly
        if (this.blurTimeout) {
            window.clearTimeout(this.blurTimeout);
        }
        this.hasFocus = false;
    }

    handleFocus() {
        // Prevent action if selection is not allowed
        if (!this.isSelectionAllowed()) {
            return;
        }
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

}