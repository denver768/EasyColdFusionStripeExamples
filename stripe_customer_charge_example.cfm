<!--- A simple one page ColdFusion example to create a customer and charge them using Stripe. --->
<!--- 2015 original built and shared by Alan Johnson, alan@westcompass.com --->
<!--- I hope this helps make integrating your ColdFusion project into Stripe easy! --->
<!--- If this saves you time, use a little of that time to do something nice for someone. --->
<cfoutput>
    <cfset TotalFee =  "45.50" >
    <cfset TotalFeeInCents =  NumberFormat(TotalFee*100,'999999')>
    <cfparam name="form.submitted" type="string" default="0" />
</cfoutput>

  <script type="text/javascript" src="https://js.stripe.com/v2/"></script>
  <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"></script>

  <!--- jQuery to intercept original form submission, get the stripeToken, add it to the form and resubmit the form --->
  <script type="text/javascript">
    <cfoutput>
        Stripe.setPublishableKey( "PutYourStripePUBLICKeyHERE" );
    </cfoutput>

    var stripeResponseHandler = function(status, response) {
      var $form = $('#payment-form');

      if (response.error) {
        // Show the errors on the form
        $form.find('.payment-errors').text(response.error.message);
        $form.find('button').prop('disabled', false);
      } else {
        // token contains id, last4, and card type
        var token = response.id;
        //alert("Token: " + token);
        // Insert the token into the form so it gets submitted to the server
        $form.append($('<input type="hidden" data-stripe="stripeToken" name="stripeToken" />').val(token));
        $form.append($('<input type="hidden" name="submitted" />').val(1));

        // and re-submit form with newly created stripeToken and submitted set to 1
        $form.get(0).submit();
        //alert($form.serialize());
      }
    };

    jQuery(function($) {
      $('#payment-form').submit(function(e) {
        var $form = $(this);

        // Disable the submit button to prevent repeated clicks
        $form.find('button').prop('disabled', true);

        Stripe.card.createToken($form, stripeResponseHandler);

        // Prevent the form from submitting with the default action
        return false;
      });
    });
  </script>

<cfoutput>
<!---Create an errors collection.--->
<cfset errors = [] />

  <!---
    When form is resubmitted, form.submitted (which we have add to the submission in the jquery) will be true.
    So now it's time to create a new customer using the stripe token, then charge the customer using the stripe customer.id
  --->
  <cfif form.submitted>
    <cfif !len( form.stripeToken )>
        <cfset arrayAppend( errors, "Something went wrong with your credit card information. Please double-check your information.  If this continues, please contact us." ) />
    </cfif>
      <cfif !arrayLen( errors )>
        <!--- Add and Save NEW Customer --->
        <cfif PersonIsAlreadyExistingCustomer NEQ 1 >
        <cftry>
            <!--- using secret Test Key --->
            <cfhttp result="customer" method="POST" url="https://api.stripe.com/v1/customers"
                username="PutYourSECRETStripeKeyHERE"
                password="">
                <!--- Email --->
                <cfhttpparam
                    type="formfield"
                    name="email"
                    value="name@customeremail.com"
                    />
                <!--- Token --->
                <cfhttpparam
                    type="formfield"
                    name="source"
                    value="#form.stripeToken#"
                    />
                <!--- A description --->
                <cfhttpparam
                    type="formfield"
                    name="description"
                    value="FirstName_LastName"
                    />
              </cfhttp>

            <!--- Deserialize the response. --->
            <cfset response = deserializeJSON( customer.fileContent ) />

            <!---  Check to see if an ERROR key exists. --->
            <cfif structKeyExists( response, "error" )>
                <!--- Add the message to the errors. --->
                  <cfset arrayAppend(errors,response.error.message) />
                <!--- Throw an errors to break the processing. --->
                  <cfthrow type="InvalidRequestError" />
            </cfif>

            <!--- set customer.id --->
              <cfset Customer_ID = response.id >

            <!--- Invalid request errors. --->
            <cfcatch type="InvalidRequestError">
                <!--- Nothing to do here. --->
            </cfcatch>

            <!--- Unexpected errors. --->
            <cfcatch>
                <cfset arrayAppend(
                    errors,
                    "There was an unexpected error during the set-up of your customer record.  If this continues, please contact us.") />
            </cfcatch>
        </cftry>
        </cfif>

        <cfif !arrayLen( errors )>
        <!--- Make the charge and go to thank you page --->
        <cftry>
            <!--- using secret Test Key --->
            <cfhttp result="charge" method="POST" url="https://api.stripe.com/v1/charges"
                username="PutYourSECRETStripeKeyHERE"
                password="">
                <!--- fee amount (in cents). --->
                <cfhttpparam type="formfield"
                    name="amount"
                    value="#Trim(TotalFeeInCents)#"
                    />
                <!--- Currency --->
                <cfhttpparam
                    type="formfield"
                    name="currency"
                    value="USD"
                    />
                <cfif PersonIsAlreadyExistingCustomer IS 1 >
                  <!--- Use Token --->
                  <cfhttpparam
                      type="formfield"
                      name="source"
                      value="#form.stripeToken#"
                      />
                <cfelse>
                  <!--- Use CustomerId --->
                  <cfhttpparam
                      type="formfield"
                      name="customer"
                      value="#Customer_ID#"
                      />
                </cfif>
                <!--- A description --->
                <cfhttpparam
                    type="formfield"
                    name="description"
                    value="Some Order Description here."
                    />
              </cfhttp>

            <!--- Deserialize the response. --->
            <cfset response = deserializeJSON( charge.fileContent ) />

            <!---  Check to see if an ERROR key exists. --->
            <cfif structKeyExists( response, "error" )>
                <!--- Add the message to the errors. --->
                  <cfset arrayAppend(errors,response.error.message) />
                <!--- Throw an errors to break the processing. --->
                  <cfthrow type="InvalidRequestError" />
            </cfif>

            <!--- successfully processed the credit card--->
              <cflocation url="SendCustomerToThankYou.cfm" addtoken="No">
              <cfabort>

            <!--- Invalid request errors. --->
            <cfcatch type="InvalidRequestError">
                <!--- Nothing to do here. --->
            </cfcatch>

            <!--- Unexpected errors. --->
            <cfcatch>
                <cfset arrayAppend(
                    errors,
                    "There was an unexpected error during the processing of your payment.  If this continues, please contact us.") />
            </cfcatch>
        </cftry>
        </cfif>
      </cfif>
  </cfif>

 <!--- the UI visible form and error dumping --->
 <!-- START THE FEATURETTES -->
  <!--- A little twitter bootstrap html, getbootstrap.com --->
    <div class="featurette-divider">
      <h1>&nbsp;</h1><p>&nbsp;</p>
      <div class="container marketing">
        <div class="row featurette">
        <div class="col-md-12">
          <h2 class="featurette-heading">Complete Order<span class="text-muted"></h2>
          <p class="lead">Please Click on the Button below to charge your credit card and complete your order.</p>
          <p><strong>Total Amount: #TotalFee# USD</strong></p>
          <!--- Immediately Below is to report errors if they exist when resubmitting through to Stripe --->
          <span class="payment-errors"></span>
          <noscript><p>JavaScript is required for the registration form.</p></noscript>
          <cfif (form.submitted && arrayLen( errors ))>
            <p>
                Please review the following errors:
            </p>
            <ul>
                <!--- Output the list of errors. --->
                <cfloop
                    index="error"
                    array="#errors#">
                    <li>
                        #error#
                    </li>
                </cfloop>
            </ul>
          </cfif>
          <!--- This where you would have your form. In this case, we're just setting some hidden form fields.
          Action here resubmits to itself as a page.  Don't worry, you'll redirect to another thankyou page momentarily.
          --->
          <form method="post" action="stripe_customer_charge_example.cfm" id="payment-form">
              <!--- You can make your own form, setting hidden variables here as an example --->
              <input type="hidden" name="currency" data-stripe="currency" value="USD">
              <input type="hidden" name="amount" data-stripe="amount" value="#Trim(TotalFeeInCents)#">

              <input type="hidden" name="name" data-stripe="name" value="Johnny Cardholder">
              <input type="hidden" name="address_line1" data-stripe="address_line1" value="123 Main Street">
              <input type="hidden" name="address_line2" data-stripe="address_line2" value="Suite 300">
              <input type="hidden" name="address_city" data-stripe="address_city" value="Denver">
              <input type="hidden" name="address_state" data-stripe="address_state" value="CO">
              <input type="hidden" name="address_zip" data-stripe="address_zip" value="80206">
              <input type="hidden" name="address_country" data-stripe="billing_country" value="US">

              <input type="hidden" data-stripe="exp-month" value="11">
              <input type="hidden" data-stripe="exp-year" value="2020">
              <input type="hidden" data-stripe="number" value="4242424242424242">
              <input type="hidden" data-stripe="cvc" value="111">
            <div class="form-group">
              <button type="submit" class="btn btn-primary">Complete Order <span class="glyphicon glyphicon-chevron-right"></span></button>
            </div>
          </form>
        </div>
      </div>
      <hr/>
<!-- /END THE FEATURETTES -->
</cfoutput>





