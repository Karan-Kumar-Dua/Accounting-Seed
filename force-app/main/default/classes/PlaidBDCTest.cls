public with sharing class PlaidBDCTest {

    public static Final String ACCESS_TOKEN_TEST_JSON = '{' +
        '"access_token": "access-sandbox-2d22d222-2dd2-222d-222d-2d222d222222",' +
        '"item_id": "RqXeZp9W8BidE3KTwRzoSk98V4lx7RHRXQ58x",'+
        '"request_id": "CaHbFrnQW2A6G1H"' +
        '}';

    public static Final String FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON = '{' + 
    '"item": {' +
        '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"credit_details",' +
        '"identity",' +
        '"income",' +
        '"transactions"' +
        '],' +
        '"billed_products": [' +
        '"auth"' +
        '],' +
        '"error": null,' +
        '"institution_id": "ins_3",' +
        '"item_id": "yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9",' +
        '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    '},' +
    '"request_id": "JQ3wz"' +
    '}' + ';' + 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
    public static Final String TRANSACTION_TEST_JSON=
    '{' +
        '"accounts": [' +
            '{' +
            '"account_id": "AS_Bank_Identity_Acc_0",' +
            '"balances": {' +
                '"available": 110,' +
                '"current": 110,' +
                '"iso_currency_code": "USD",' +
                '"limit": null,' +
                '"unofficial_currency_code": null' +
            '},' +
            '"mask": "0000",' +
            '"name": "Plaid Checking",' +
            '"official_name": "Plaid Gold Standard 0% Interest Checking",' +
            '"subtype": "checking",' +
            '"type": "depository"' +
            '}' +
        '],' +
        '"transactions": [' +
            '{' +
            '"account_id": "AS_Bank_Identity_Acc_0",' +
            '"amount": 2307.21,' +
            '"iso_currency_code": "USD",' +
            '"unofficial_currency_code": null,' +
            '"category": [' +
                '"Shops",' +
                '"Computers and Electronics"' +
            '],' +
            '"category_id": "12008000",' +
            '"check_number": null,' +
            '"date": "2022-11-02",' +
            '"datetime": "2022-11-02T11:00:00Z",' +
            '"authorized_date": "2022-11-02",' +
            '"authorized_datetime": "2022-11-02T10:34:50Z",' +
            '"location": {' +
                '"address": "300 Post St",' +
                '"city": "San Francisco",' +
                '"region": "CA",' +
                '"postal_code": "94108",' +
                '"country": "US",' +
                '"lat": 40.740352,' +
                '"lon": -74.001761,' +
                '"store_number": "1235"' +
            '},' +
            '"name": "Apple Store",' +
            '"merchant_name": "Apple",' +
            '"payment_meta": {' +
                '"by_order_of": null,' +
                '"payee": null,' +
                '"payer": null,' +
                '"payment_method": null,' +
                '"payment_processor": null,' +
                '"ppd_id": null,' +
                '"reason": null,' +
                '"reference_number": null' +
            '},' +
            '"payment_channel": "in store",' +
            '"pending": false,' +
            '"pending_transaction_id": null,' +
            '"account_owner": null,' +
            '"transaction_id": "lPNjeW1nR6CDn5okmGQ6hEpMo4lLNoSrzqDje",' +
            '"transaction_code": null,' +
            '"transaction_type": "place"' +
            '}' +
        '],' +
        '"item": {' +
            '"available_products": [' +
            '"balance",' +
            '"identity",' +
            '"investments"' +
            '],' +
            '"billed_products": [' +
            '"assets",' +
            '"auth",' +
            '"liabilities",' +
            '"transactions"' +
            '],' +
            '"consent_expiration_time": null,' +
            '"error": null,' +
            '"institution_id": "ins_3",' +
            '"item_id": "yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9",' +
            '"update_type": "background",' +
            '"webhook": "https://www.genericwebhookurl.com/webhook"' +
        '},' +
        '"total_transactions": 1,' +
        '"request_id": "45QSn"' +
    '}'+ ';' + 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

    public static Final String FINANCIAL_INSTITUTIONS_TEST_JSON = '{' +
    '"institution": {' +
        '"credentials": [' +
        '{' +
            '"label": "User ID",' +
            '"name": "username",' +
            '"type": "text"' +
        '},' +
        '{' +
            '"label": "Password",' +
            '"name": "password",' +
            '"type": "password"' +
        '}' +
        '],' +
        '"has_mfa": true,' +
        '"institution_id": "ins_3",' +
        '"mfa": [' +
        '"code",' +
        '"list"' +
        '],' +
        '"mfa_code_type": "numeric",' +
        '"name": "Chase",' +
        '"products": [' +
        '"assets",' +
        '"auth",' +
        '"balance",' +
        '"transactions",' +
        '"credit_details",' +
        '"income",' +
        '"identity"' +
        ']' +
    '},' +
    '"request_id": "WTa7v"' +
'}';

public static Final String CATEGORIES_TEST_JSON = '{' + 
        '"categories": [' +
            '{' +
            '"category_id": "12000000",' +
            '"group": "place",' +
            '"hierarchy": [' +
                '"Shops"' +
            ']' +
            '},' +
                '{' +
            '"category_id": "12008000",' +
            '"group": "place",' +
            '"hierarchy": [' +
                '"Shops",' +
                '"Computers and Electronics"' +
            ']' +
            '},' +
            '{' +
            '"category_id": "12008001",' +
            '"group": "place",' +
            '"hierarchy": [' +
                '"Shops",' +
                '"Computers and Electronics",' +
                '"Mobile Phones"' +
            ']' +
        '}' +
        '],' +
        '"request_id": "bn8Uv"' +
    '}';

    public static Final String ACCOUNT_TEST_JSON = '{' +
    '"accounts": [' +
        '{' +
        '"account_id": "PnpkZlD1rDtQZ7oxk97kSd3xJxz1pwf7bgeLk",' +
        '"balances": {' +
            '"available": 100,' +
            '"current": 110,' +
            '"iso_currency_code": "CAD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "0000",' +
        '"name": "Plaid Checking",' +
        '"official_name": "Plaid Gold Standard 0% Interest Checking",' +
        '"subtype": "checking",' +
        '"type": "depository"' +
        '},' +
        '{' +
        '"account_id": "eNVMxpWB6WFpQmr8gvmgi3woAoQP5aHLKpbvG",' +
        '"balances": {' +
            '"available": 200,' +
            '"current": 210,' +
            '"iso_currency_code": "CAD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "1111",' +
        '"name": "Plaid Saving",' +
        '"official_name": "Plaid Silver Standard 0.1% Interest Saving",' +
        '"subtype": "savings",' +
        '"type": "depository"' +
        '},' +
        '{' +
        '"account_id": "jQVLmWn4pnCokXGzlpXlSEKkXkd6AbT1kD7K4",' +
        '"balances": {' +
            '"available": null,' +
            '"current": 1000,' +
            '"iso_currency_code": "CAD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "2222",' +
        '"name": "Plaid CD",' +
        '"official_name": "Plaid Bronze Standard 0.2% Interest CD",' +
        '"subtype": "cd",' +
        '"type": "depository"' +
        '},' +
        '{' +
        '"account_id": "QbopGqDLzDCmZp7aM9pMhoeywyR1xnSpLvgPn",' +
        '"balances": {' +
            '"available": null,' +
            '"current": 410,' +
            '"iso_currency_code": "CAD",' +
            '"limit": 2000,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "3333",' +
        '"name": "Plaid Credit Card",' +
        '"official_name": "Plaid Diamond 12.5% APR Interest Credit Card",' +
        '"subtype": "credit card",' +
        '"type": "credit"' +
        '},' +
        '{' +
        '"account_id": "7zAR5KDnPDfybrlMj9rjUrQGNGVMBpCgze5bP",' +
        '"balances": {' +
            '"available": 43200,' +
            '"current": 43200,' +
            '"iso_currency_code": "CAD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "4444",' +
        '"name": "Plaid Money Market",' +
        '"official_name": "Plaid Platinum Standard 1.85% Interest Money Market",' +
        '"subtype": "money market",' +
        '"type": "depository"' +
        '}' +
    '],' +
    '"item": {' +
        '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"identity",' +
        '"income",' +
        '"transactions"' +
        '],' +
        '"billed_products": [' +
        '"auth"' +
        '],' +
        '"error": null,' +
        '"institution_id": "ins_43",' +
        '"item_id": "wnVRXPmk3mt3wepjXEeXsbN4NWe5V9FrNeEN1",' +
        '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    '},' +
    '"request_id": "xBULJ"' +
'}';

public static Final String ACCOUNT_TEST_JSON_NULL_ACCT_NAME = '{' +
    '"accounts": [' +
        '{' +
        '"account_id": "PnpkZlD1rDtQZ7oxk97kSd3xJxz1pwf7bgeLk",' +
        '"balances": {' +
            '"available": 100,' +
            '"current": 110,' +
            '"iso_currency_code": "CAD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "0000",' +
        '"name": "Plaid Checking",' +
        '"official_name": null,' +
        '"subtype": "checking",' +
        '"type": "depository"' +
        '},' +
    '],' +
    '"item": {' +
        '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"identity",' +
        '"income",' +
        '"transactions"' +
        '],' +
        '"billed_products": [' +
        '"auth"' +
        '],' +
        '"error": null,' +
        '"institution_id": "ins_43",' +
        '"item_id": "wnVRXPmk3mt3wepjXEeXsbN4NWe5V9FrNeEN1",' +
        '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    '},' +
    '"request_id": "xBULJ"' +
'}';

    public static Final String FINANCIAL_INSTITUTIONS_IDENTITITES_DELETE_TEST_JSON = '{' +
        '"request_id": "TxV5g0HqdD5lOJn"' +
    '}';

    public static Final String ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON = '{' +
    '"accounts": [' +
    '{' +
        '"account_id": "j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv",' +
        '"balances": {' +
            '"available": 100,' +
            '"current": 110,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "0000",'+
        '"name": "Plaid Checking",' +
        '"official_name": "Plaid Gold Standard 0% Interest Checking",' +
        '"subtype": "checking",' +
        '"type": "depository"' +
    '},' +
    ' {' +
        '"account_id": "7nb9NbQr8GHy963VVNGbcJM1pBVJWei11mplM",' +
        '"balances": {' +
            '"available": 200,' +
            '"current": 210,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "1111",' +
        '"name": "Plaid Saving",' +
        '"official_name": "Plaid Silver Standard 0.1% Interest Saving",' +
        '"subtype": "savings",' +
        '"type": "depository"' +
    '},' +
    '{' +
        '"account_id": "eBXmDXaZb9Upv7ezzb1QC4PLa5Q4mWuVVzkdV",' +
        '"balances": {' +
            '"available": null,' +
            '"current": 1000,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
    ' },' +
        '"mask": "2222",' +
        '"name": "Plaid CD",' +
        '"official_name": "Plaid Bronze Standard 0.2% Interest CD",' +
        '"subtype": "cd",' +
        '"type": "depository"' +
    '},' +
    '{' +
        '"account_id": "QLM3AMVn9jIm9PKooGNZi51znxR5VJTaaJeMz",' +
        '"balances": {' +
            '"available": null,' +
            '"current": 410,' +
            '"iso_currency_code": "USD",' +
            '"limit": 2000,' +
            '"unofficial_currency_code": null' +
    ' },' +
        '"mask": "3333",' +
        '"name": "Plaid Credit Card",' +
        '"official_name": "Plaid Diamond 12.5% APR Interest Credit Card",' +
        '"subtype": "credit card",' +
        '"type": "credit"' +
    '},' +
    '{' +
        '"account_id": "ZnMmAMg3doHG9x8mmJ3WcB3oAzqBaWCbbNlRP",' +
        '"balances": {' +
            '"available": 43200,' +
            '"current": 43200,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "4444",' +
        '"name": "Plaid Money Market",' +
        '"official_name": "Plaid Platinum Standard 1.85% Interest Money Market",' +
        '"subtype": "money market",' +
        '"type": "depository"' +
    ' },' +
    '{' +
        '"account_id": "MQ4KV4wkEaiGMgEqqjPoc1LkRpn1zmc77Eylm",' +
        '"balances": {' +
            '"available": null,' +
            '"current": 320.76,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "5555",' +
        '"name": "Plaid IRA",' +
        '"official_name": null,' +
        '"subtype": "ira",' +
        '"type": "investment"' +
    ' },' +
    '{' +
        '"account_id": "1gV9BVynPouWJjGppPBmiQ8MGWKQxaUmmxoKV",' +
        '"balances": {' +
            '"available": null,' +
            '"current": 23631.9805,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "6666",' +
        '"name": "Plaid 401k",' +
        '"official_name": null,' +
        '"subtype": "401k",' +
        '"type": "investment"' +
    '},' +
    '{' +
        '"account_id": "BBZ3WZl7rVU8xroppQlJiNyerEzNP4CLLQjWV",' +
        '"balances": {' +
            '"available": null,' +
            '"current": 65262,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
        '},' +
        '"mask": "7777",' +
        '"name": "Plaid Student Loan",' +
        '"official_name": null,' +
        '"subtype": "student",' +
        '"type": "loan"' +
    ' },' +
    '{' +
        '"account_id": "3Eb9xbBmQ8tbJ6gLLZyPswrvKVWw5oS88BRrN",' +
    ' "balances": {' +
            ' "available": null,' +
            '"current": 56302.06,' +
            '"iso_currency_code": "USD",' +
            '"limit": null,' +
            '"unofficial_currency_code": null' +
    ' },' +
        '"mask": "8888",' +
        '"name": "Plaid Mortgage",' +
        '"official_name": null,' +
        '"subtype": "mortgage",' +
        '"type": "loan"' +
    '}' +
    ' ],' +
    '"item": {' +
    '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"credit_details",' +
        '"identity",' +
        '"income",' +
        '"investments",' +
        '"liabilities"' +
    '],' +
    '"billed_products": [' +
        '"auth",' +
        '"transactions"' +
    '],' +
    '"consent_expiration_time": null,' +
    '"error": null,' +
    '"institution_id": "ins_3",' +
    '"item_id": "yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9",' +
    '"optional_products": null,' +
    '"products": [' +
    ' "auth",' +
        '"transactions"' +
    '],' +
    ' "update_type": "background",' +
    '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    ' },' +
    '"request_id": "lnwE2IwPuyQOQsp"' +
    ' }';

    public static Final String ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_NAME = '{' +
    '"accounts": [' +
        '{' +
            '"account_id": "j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv",' +
            '"balances": {' +
                '"available": 100,' +
                '"current": 110,' +
                '"iso_currency_code": "USD",' +
                '"limit": null,' +
                '"unofficial_currency_code": null' +
            '},' +
            '"mask": "0000",'+
            '"name": "Plaid Checking",' +
            '"official_name": null,' +
            '"subtype": "checking",' +
            '"type": "depository"' +
        '}' +
    ' ],' +
    '"item": {' +
    '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"credit_details",' +
        '"identity",' +
        '"income",' +
        '"investments",' +
        '"liabilities"' +
    '],' +
    '"billed_products": [' +
        '"auth",' +
        '"transactions"' +
    '],' +
    '"consent_expiration_time": null,' +
    '"error": null,' +
    '"institution_id": "ins_3",' +
    '"item_id": "yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9",' +
    '"optional_products": null,' +
    '"products": [' +
    ' "auth",' +
        '"transactions"' +
    '],' +
    ' "update_type": "background",' +
    '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    ' },' +
    '"request_id": "lnwE2IwPuyQOQsp"' +
    ' }';

    public static Final String ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_NICKNAME = '{' +
    '"accounts": [' +
        '{' +
            '"account_id": "j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv",' +
            '"balances": {' +
                '"available": 100,' +
                '"current": 110,' +
                '"iso_currency_code": "USD",' +
                '"limit": null,' +
                '"unofficial_currency_code": null' +
            '},' +
            '"mask": "0000",'+
            '"name": null,' +
            '"official_name": "Plaid Gold Standard 0% Interest Checking",' +
            '"subtype": "checking",' +
            '"type": "depository"' +
        '}' +
    ' ],' +
    '"item": {' +
    '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"credit_details",' +
        '"identity",' +
        '"income",' +
        '"investments",' +
        '"liabilities"' +
    '],' +
    '"billed_products": [' +
        '"auth",' +
        '"transactions"' +
    '],' +
    '"consent_expiration_time": null,' +
    '"error": null,' +
    '"institution_id": "ins_3",' +
    '"item_id": "yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9",' +
    '"optional_products": null,' +
    '"products": [' +
    ' "auth",' +
        '"transactions"' +
    '],' +
    ' "update_type": "background",' +
    '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    ' },' +
    '"request_id": "lnwE2IwPuyQOQsp"' +
    ' }';

    public static Final String ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_ACCT_MASK = '{' +
    '"accounts": [' +
        '{' +
            '"account_id": "j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv",' +
            '"balances": {' +
                '"available": 100,' +
                '"current": 110,' +
                '"iso_currency_code": "USD",' +
                '"limit": null,' +
                '"unofficial_currency_code": null' +
            '},' +
            '"mask": null,'+
            '"name": "Plaid Checking",' +
            '"official_name": "Plaid Gold Standard 0% Interest Checking",' +
            '"subtype": "checking",' +
            '"type": "depository"' +
        '}' +
    ' ],' +
    '"item": {' +
    '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"credit_details",' +
        '"identity",' +
        '"income",' +
        '"investments",' +
        '"liabilities"' +
    '],' +
    '"billed_products": [' +
        '"auth",' +
        '"transactions"' +
    '],' +
    '"consent_expiration_time": null,' +
    '"error": null,' +
    '"institution_id": "ins_3",' +
    '"item_id": "yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9",' +
    '"optional_products": null,' +
    '"products": [' +
    ' "auth",' +
        '"transactions"' +
    '],' +
    ' "update_type": "background",' +
    '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    ' },' +
    '"request_id": "lnwE2IwPuyQOQsp"' +
    ' }';

    public static Final String ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_ACCT_INFO = '{' +
    '"accounts": [' +
        '{' +
            '"account_id": "j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv",' +
            '"balances": {' +
                '"available": 100,' +
                '"current": 110,' +
                '"iso_currency_code": "USD",' +
                '"limit": null,' +
                '"unofficial_currency_code": null' +
            '},' +
            '"mask": null,'+
            '"name": null,' +
            '"official_name": null,' +
            '"subtype": "checking",' +
            '"type": "depository"' +
        '}' +
    ' ],' +
    '"item": {' +
    '"available_products": [' +
        '"assets",' +
        '"balance",' +
        '"credit_details",' +
        '"identity",' +
        '"income",' +
        '"investments",' +
        '"liabilities"' +
    '],' +
    '"billed_products": [' +
        '"auth",' +
        '"transactions"' +
    '],' +
    '"consent_expiration_time": null,' +
    '"error": null,' +
    '"institution_id": "ins_3",' +
    '"item_id": "yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9",' +
    '"optional_products": null,' +
    '"products": [' +
    ' "auth",' +
        '"transactions"' +
    '],' +
    ' "update_type": "background",' +
    '"webhook": "https://www.genericwebhookurl.com/webhook"' +
    ' },' +
    '"request_id": "lnwE2IwPuyQOQsp"' +
    ' }';

    public static Final String TRANSACTION_FAILED_TEST_JSON = '{' +
        '"error_type": "RATE_LIMIT_EXCEEDED",' +
        '"error_code": "TRANSACTIONS_LIMIT", ' +
        '"error_message": "rate limit exceeded for attempts to access this item. please try again later",' +
        '"display_message": null,' +
        '"request_id": "HNTDNrA8F1shFEW"' +
       '}' + ';' + 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

    public static Final String TRANSACTION_NOT_READY_TEST_JSON = '{' +
        '"display_message": null,' +
        '"documentation_url": "https://plaid.com/docs/?ref=error#item-errors",' +
        '"error_code": "PRODUCT_NOT_READY", ' +
        '"error_message": "the requested product is not yet ready. please provide a webhook or try the request again later",' +
        '"error_type": "ITEM_ERROR",' +
        '"request_id": "HNTDNrA8F1shFEW",' +
        '"suggested_action": null' +
       '}' + ';' + 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

    public static Final String ACCOUNT_FAILED_TEST_JSON = '{' +
       '"error_type": "ITEM_ERROR",' +
       '"error_code": "NO_ACCOUNTS",' +
       '"error_message": "no valid accounts were found for this item",' +
       '"display_message": "No valid accounts were found at the financial institution. Please visit your financial institution\'' + 's website to confirm accounts are available.",' +
       '"request_id": "HNTDNrA8F1shFEW"' +
      '}';

    public static Final String FINANCIAL_INSTITUTIONS_FAILED_TEST_JSON = '{' +
       '"error_type": "INSTITUTION_ERROR",' +
       '"error_code": "INSTITUTION_DOWN",' +
       '"error_message": "this institution is not currently responding to this request. please try again soon",' +
       '"display_message": "This financial institution is not currently responding to requests. We apologize for the inconvenience.",' +
       '"request_id": "HNTDNrA8F1shFEW"' +
      '}';

    public static Final String FINANCIAL_INSTITUTIONS_IDENTITITES_FAILED_TEST_JSON = '{' +
       '"error_type": "INSTITUTION_ERROR",' +
       '"error_code": "INSTITUTION_NOT_FOUND",' +
       '"error_message": "this institution was not found. Please check the ID supplied",' +
       '"display_message": null,' +
       '"request_id": "HNTDNrA8F1shFEW"' +
      '}' + ';' + 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

    public static Final String CATEGORIES_FAILED_TEST_JSON = '{' +
      '"error_type": "TRANSACTIONS_ERROR",' +
      '"error_code": "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION",' +
      '"error_message": "Underlying transaction data changed since last page was fetched. Please restart pagination from last update.",' +
      '"display_message": null,' +
      '"request_id": "HNTDNrA8F1shFEW"' +
     '}';

    public static Final String FINANCIAL_IDENTIIES_DELETE_FAILED_TEST_JSON = '{' +
        '"display_message": null,' +
        '"documentation_url": "https://plaid.com/docs/?ref=error#item-errors",' +
        '"error_code": "ITEM_NOT_FOUND",' +
        '"error_message": "The Item you requested cannot be found. This Item does not exist, has been previously removed via /item/remove, or has had access removed by the user.",' +
        '"error_type": "ITEM_ERROR",' +
        '"request_id": "GIu8mBj99mRlr0E",' +
        '"suggested_action": null' +
    '}';
    public static String TRANSACTION_BULK_TEST_JSON() {
        String testResponseText = [SELECT Id, body FROM staticResource Where NAME = 'PlaidBulkTestText'][0].body.toString();
        return testResponseText;
    }
}