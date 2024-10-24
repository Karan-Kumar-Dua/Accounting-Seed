import Lookup from 'c/lookup';
import { api } from 'lwc';
//import apexSearchByDateRange from '@salesforce/apex/LookupHelper.searchByDateRange';

export default class LookupByDateRange extends Lookup {

    @api startDate;     // start of range (optional)
    @api endDate;       // end of range (optional)
    @api dateField;     // field of type Date to filter on (required)

    // override parent function
    search(params) {
        params.startDate = this.startDate;
        params.endDate = this.endDate;
        params.dateField = this.dateField;
        //return apexSearchByDateRange(params);
    }

}