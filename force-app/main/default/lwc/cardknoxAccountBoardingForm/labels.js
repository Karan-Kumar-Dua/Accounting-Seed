//cardknox
import modalHeader from '@salesforce/label/c.CRDKNX_MODAL_HEADER';
import step1 from '@salesforce/label/c.CRDKNX_STEP_1';
import step2 from '@salesforce/label/c.CRDKNX_STEP_2';
import step3 from '@salesforce/label/c.CRDKNX_STEP_3';
import step4 from '@salesforce/label/c.CRDKNX_STEP_4';
import complete from '@salesforce/label/c.CRDKNX_COMPLETE';
import companyName from '@salesforce/label/c.CRDKNX_COMPANY_NAME';
import dbaName from '@salesforce/label/c.CRDKNX_DBA_NAME';
import business from '@salesforce/label/c.CRDKNX_BUSINESS';
import startDate from '@salesforce/label/c.CRDKNX_START_DATE';
import industry from '@salesforce/label/c.CRDKNX_INDUSTRY';
import productService from '@salesforce/label/c.CRDKNX_PRODUCT';
import phone from '@salesforce/label/c.CRDKNX_PHONE';
import taxId from '@salesforce/label/c.CRDKNX_TAX_ID';
import website from '@salesforce/label/c.CRDKNX_WEBSITE';
import priorSale from '@salesforce/label/c.CRDKNX_PRIOR_YEAR_CR_SALE';
import email from '@salesforce/label/c.CRDKNX_EMAIL';
import ownerName from '@salesforce/label/c.CRDKNX_OWNER_NAME';
import ownerEmail from '@salesforce/label/c.CRDKNX_OWNER_EMAIL';
import bankDetails from '@salesforce/label/c.CRDKNX_BANK_DETAILS';
import bankName from '@salesforce/label/c.CRDKNX_BANK_NAME';
import accountNumber from '@salesforce/label/c.COMMON_ACCOUNT_NUMBER';
import routing from '@salesforce/label/c.COMMON_ROUTING_NUMBER';
import baAddress from '@salesforce/label/c.CRDKNX_BA_ADDRESS';
import baStreet from '@salesforce/label/c.COMMON_STREET_ADDRESS';
import baCity from '@salesforce/label/c.CRDKNX_BA_CITY';
import baCountry from '@salesforce/label/c.CRDKNX_BA_COUNTRY';
import baState from '@salesforce/label/c.CRDKNX_BA_STATE';
import baZip from '@salesforce/label/c.CRDKNX_BA_ZIP';
import maAddress from '@salesforce/label/c.CRDKNX_MA_ADDRESS';
import baMaSame from '@salesforce/label/c.CRDKNX_BA_MA_SAME';
import signer from '@salesforce/label/c.CRDKNX_SIGNER';
import note from '@salesforce/label/c.CRDKNX_NOTE';
import firstName from '@salesforce/label/c.CRDKNX_FIRST_NAME';
import lastName from '@salesforce/label/c.CRDKNX_LAST_NAME';
import ownerPercent from '@salesforce/label/c.CRDKNX_OWNER_PERCENTAGE';
import title from '@salesforce/label/c.CRDKNX_TITLE';
import ssn from '@salesforce/label/c.CRDKNX_SSN';
import cellNumber from '@salesforce/label/c.CRDKNX_CELL_NUMBER';
import iAgree from '@salesforce/label/c.CRDKNX_I_AGREE';
import terms from '@salesforce/label/c.CRDKNX_TERMS';
import dob from '@salesforce/label/c.CRDKNX_DOB';
import soleProp from '@salesforce/label/c.CRDKNX_SOLE_PROP';
import partnership from '@salesforce/label/c.CRDKNX_PARTNERSHIP';
import corporation from '@salesforce/label/c.CRDKNX_CORPORATION';
import soleOwner from '@salesforce/label/c.CRDKNX_SOLE_OWNERSHIP';
import llcNp from '@salesforce/label/c.CRDKNX_LLC_NP';
import submit from '@salesforce/label/c.COMMON_SUBMIT';
import crdError from '@salesforce/label/c.ERR_CRDKNX_FORM_ERROR_MESSAGE';
import crdSuccess from '@salesforce/label/c.INF_CRDKNX_FORM_SUCCESS';
import agreementFormHeader from '@salesforce/label/c.CRDKNX_AGREEMENT_FORM';
import telephonePatternMismatch from '@salesforce/label/c.CRDKNX_TELEPHONE_PATTERN_MISMATCH';
import addSigner from '@salesforce/label/c.CRDKNX_ADD_SIGNER';

//cardknox merchant account info form field errors
import errMustBe128CharactersOrLess from '@salesforce/label/c.ERR_MUST_BE_128_CHARACTER_OR_LESS';
import errMustBe64CharactersOrLess from '@salesforce/label/c.ERR_MUST_BE_64_CHARACTER_OR_LESS';
import errMustBe32CharactersOrLess from '@salesforce/label/c.ERR_MUST_BE_32_CHARACTER_OR_LESS';
import errMustBe50CharactersOrLess from '@salesforce/label/c.ERR_MUST_BE_50_CHARACTER_OR_LESS';
import errPhoneNumberMustBe10Digits from '@salesforce/label/c.ERR_PHONE_NUMBER_MUST_BE_10_DIGITS';
import errMustBe9Digits from '@salesforce/label/c.ERR_MUST_BE_9_DIGITS';
import errInvalidEmailAddress from '@salesforce/label/c.ERR_INVALID_EMAIL_ADDRESS';
import errMustBeBetween5and17Character from '@salesforce/label/c.ERR_MUST_BE_BETWEEN_5_AND_17_CHARACTERS';
import errMustBe5Digits from '@salesforce/label/c.ERR_MUST_BE_5_DIGITS';
import errMustBe64CharactersOrLessWithoutNumeric from '@salesforce/label/c.ERR_MUST_BE_64_CHARACTER_OR_LESS_WITHOUT_NUMERIC';
import errMustSumUpTo100Percent from '@salesforce/label/c.ERR_MUST_SUM_UP_TO_100_PERCENT';
import errMinimumAgeIs18Years from '@salesforce/label/c.ERR_MINIMUM_AGE_IS_18_YEARS';
import errInvalidSSNNumberAndMustBe9Digits from '@salesforce/label/c.ERR_INVALID_SSN_NUMBER_MUST_BE_9_DIGITS';

const labels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    modalHeader,
    step1,
    step2,
    step3,
    step4,
    complete,
    companyName,
    dbaName,
    business,
    startDate,
    productService,
    industry,
    phone,
    taxId,
    website,
    priorSale,
    email,
    ownerName,
    ownerEmail,
    bankDetails,
    bankName,
    accountNumber,
    routing,
    baAddress,
    baStreet,
    baCity,
    baCountry,
    baState,
    baZip,
    maAddress,
    baMaSame,
    signer,
    note,
    firstName,
    lastName,
    ownerPercent,
    title,
    ssn,
    cellNumber,
    iAgree,
    terms,
    dob,
    llcNp,
    soleOwner,
    corporation,
    partnership,
    soleProp,
    submit,
    crdError,
    crdSuccess,
    agreementFormHeader,
    telephonePatternMismatch,
    errMustBe128CharactersOrLess,
    errMustBe64CharactersOrLess,
    errMustBe32CharactersOrLess,
    errMustBe50CharactersOrLess,
    errPhoneNumberMustBe10Digits,
    errMustBe9Digits,
    errInvalidEmailAddress,
    errMustBeBetween5and17Character,
    errMustBe5Digits,
    errMustBe64CharactersOrLessWithoutNumeric,
    errMustSumUpTo100Percent,
    errMinimumAgeIs18Years,
    errInvalidSSNNumberAndMustBe9Digits,
    addSigner
}
export {labels};