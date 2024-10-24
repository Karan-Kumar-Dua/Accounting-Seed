import {LightningElement, wire} from 'lwc';
import getPackageVersion from '@salesforce/apex/AccountingHomeHelper.getPackageVersion';
import getOrgId from '@salesforce/apex/AccountingHomeHelper.getOrgId';

export default class ReleaseInfo extends LightningElement {

    url = "https://www.accountingseed.com/wp-content/uploads/files/as-announcement-widget.html";

    @wire (getPackageVersion)
    packageVersion;

    @wire (getOrgId)
    orgId;

    get compUrl(){
        return  `${this.url}?org=${this.orgId.data}&version=${this.packageVersion.data}`;
    }
}