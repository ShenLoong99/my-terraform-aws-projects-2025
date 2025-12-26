import boto3
import logging

# Initialize logger for debugging in CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def build_response(message_text, intent_name, slots):
    """
    Helper function to format the Lex V2 response.
    """
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Close"
            },
            "intent": {
                "name": intent_name,
                "slots": slots,
                "state": "Fulfilled"
            }
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": message_text
            }
        ]
    }

def lambda_handler(event, context):
    logger.info(f"Received event: {event}")
    
    # 1. Extract Intent and Slots
    intent = event.get('sessionState', {}).get('intent', {})
    intent_name = intent.get('name')
    slots = intent.get('slots', {})
    
    # 2. Safely get slot values
    try:
        phrase = slots['phrase']['value']['interpretedValue']
        # Use originalValue for target_lang to get the raw user input (e.g., "Spanish" or "es")
        target_lang = slots['target_language']['value']['originalValue']
    except (KeyError, TypeError) as e:
        logger.error(f"Missing required slots: {e}")
        return build_response(
            "I'm sorry, I didn't catch the text or the language. Could you try again?",
            intent_name,
            slots
        )

    # 3. Call Amazon Translate
    translate_client = boto3.client('translate')
    
    try:
        response = translate_client.translate_text(
            Text=phrase,
            SourceLanguageCode="auto", # Automatically detects input language
            TargetLanguageCode=target_lang
        )
        translated_text = response.get('TranslatedText')
        final_message = f"Here is the translation: {translated_text}"
        
    except Exception as e:
        logger.error(f"AWS Translate Error: {str(e)}")
        final_message = "Sorry, I encountered an error while translating your text."

    # 4. Return the formatted response to Lex
    return build_response(final_message, intent_name, slots)