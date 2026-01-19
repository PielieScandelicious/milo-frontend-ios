# Dobby AI Chat - Implementation Guide

## Overview

Dobby AI Chat is an intelligent assistant that analyzes your grocery shopping data and provides personalized insights about your diet and spending habits using Anthropic's Claude AI.

## Features

✅ **Natural conversation** - Chat naturally with Dobby about your shopping habits  
✅ **Real-time data analysis** - Analyzes all your transactions to provide accurate insights  
✅ **Nutrition insights** - Get information about protein intake, vegetable consumption, etc.  
✅ **Spending insights** - Understand where your money goes and find savings opportunities  
✅ **Personalized recommendations** - Get specific suggestions based on your actual data  
✅ **Conversation history** - Maintains context throughout the conversation  

## Architecture

### Files Created

1. **DobbyAIChatService.swift** - Core AI service that:
   - Communicates with Anthropic API
   - Prepares shopping data for AI analysis
   - Calculates nutrition and spending insights
   - Formats data for the AI model

2. **DobbyAIChatView.swift** - SwiftUI chat interface with:
   - Message bubbles for user and AI
   - Welcome screen with sample questions
   - Typing indicator
   - Input field with send button
   - Conversation management

3. **ContentView.swift** - Updated to include AI chat in Dobby tab

## How It Works

### 1. Data Preparation
When you open the chat, the service:
- Loads all your transactions
- Calculates nutrition breakdown (protein, vegetables, unhealthy items)
- Calculates spending by category and store
- Formats recent transactions

### 2. System Prompt
The AI receives a detailed system prompt containing:
```
- Your total spending by category
- Protein sources spending and percentage
- Vegetable spending and percentage  
- "Less healthy" spending (snacks, alcohol, soda)
- Top spending categories
- Last 20 transactions with details
```

### 3. Conversation
Each message you send:
1. Gets added to conversation history
2. Is sent to Claude AI with full context
3. AI analyzes your data and responds
4. Response appears in chat with timestamp

## Sample Questions

The AI can answer questions like:

### Nutrition Questions
- "Do I have enough protein in my diet?"
- "Am I buying enough vegetables?"
- "How healthy is my diet?"
- "What should I buy more of?"
- "Am I eating too much junk food?"

### Spending Questions
- "What's my biggest expense category?"
- "Where can I save money?"
- "Am I spending too much on alcohol?"
- "Which store is cheapest for me?"
- "How much do I spend on snacks?"

### Comparison Questions
- "Compare my protein spending to vegetables"
- "What percentage of my budget goes to meat?"
- "Am I overspending in any category?"

### Recommendations
- "How can I eat healthier?"
- "Suggest cheaper alternatives"
- "Help me reduce my grocery bill"
- "What should I buy less of?"

## Configuration

### API Key
The service uses your Anthropic API key from `AppConfiguration.anthropicAPIKey`.

Make sure your `AppConfiguration.swift` has:
```swift
struct AppConfiguration {
    static let anthropicAPIKey = "your-api-key-here"
}
```

### Model
Currently uses: `claude-3-5-sonnet-20241022`
- Fast responses
- Excellent analysis capabilities
- Understands context well

### Token Limit
Set to 2048 tokens per response (configurable in `DobbyAIChatService.swift`)

## UI Components

### Welcome Screen
Shows when chat is empty:
- Friendly greeting
- Explanation of capabilities
- 4 sample questions to get started

### Message Bubbles
- **User messages**: Blue bubbles on the right
- **AI messages**: Gray bubbles on the left
- Timestamps below each message
- Max width 75% of screen

### Input Area
- Multi-line text field (1-5 lines)
- Send button (blue when text present, gray when empty)
- Disabled while AI is responding

### Toolbar
Menu button with options:
- Clear Conversation
- Sample Questions

### Typing Indicator
Animated 3-dot indicator while AI is thinking

## Data Privacy

✅ **All processing happens through Anthropic API** - Your data is sent to Claude for analysis  
✅ **No persistent storage of conversations** - Chats are stored in memory only  
✅ **Uses your own API key** - You control the API access  
⚠️ **Transaction data is sent to AI** - The AI needs your shopping data to provide insights  

## Error Handling

The chat handles errors gracefully:
- Network errors
- API errors
- Invalid responses
- Empty responses

Error messages appear as assistant messages in the chat.

## Customization

### Changing the AI Personality
Edit the system prompt in `buildSystemPrompt()` to change how Dobby responds:
```swift
Your personality:
- Friendly and conversational  // ← Change these
- Data-driven but explain insights in simple terms
- Proactive in suggesting improvements
- Supportive and non-judgmental
```

### Adding More Insights
Add new calculations in:
- `calculateNutritionInsights()` - For dietary analysis
- `calculateSpendingInsights()` - For financial analysis

### Changing the Model
Update in `sendRequest()`:
```swift
"model": "claude-3-5-sonnet-20241022"  // ← Change here
```

Available models:
- `claude-3-5-sonnet-20241022` - Best balance (recommended)
- `claude-3-opus-20240229` - Highest quality, slower
- `claude-3-haiku-20240307` - Fastest, cheaper

## Usage Tips

### Getting Better Responses
1. **Be specific**: "How much protein did I buy this week?" vs "Tell me about protein"
2. **Ask follow-ups**: The AI remembers conversation context
3. **Request comparisons**: "Compare my spending to last month"
4. **Ask for recommendations**: "Suggest healthier alternatives"

### Conversation Management
- Clear conversation when changing topics for better context
- Start fresh conversations for different types of questions
- Use sample questions to see what's possible

## Testing

### With Mock Data
The app includes mock transactions, so you can test immediately:
```swift
Transaction.generateMockTransactions()
```

### Adding Real Data
Import receipts through:
1. Share Extension (save receipt images)
2. Manual receipt scanning
3. Direct transaction entry

## Performance

### Response Time
- Typical response: 2-5 seconds
- Depends on API availability and network speed

### Token Usage
- System prompt: ~1000 tokens
- Typical conversation: 200-500 tokens per exchange
- Cost: ~$0.003 per message with Claude 3.5 Sonnet

### Data Limits
- Currently loads ALL transactions
- For large datasets (>1000 transactions), consider filtering to recent months

## Future Enhancements

Possible improvements:
- [ ] Save favorite conversations
- [ ] Export chat as PDF
- [ ] Voice input/output
- [ ] Charts and visualizations in responses
- [ ] Comparison with previous periods
- [ ] Budget planning features
- [ ] Meal planning suggestions
- [ ] Shopping list generation
- [ ] Recipe recommendations based on purchases

## Troubleshooting

### "Invalid API Key" Error
- Check `AppConfiguration.anthropicAPIKey` is set correctly
- Verify API key is active in Anthropic console

### "Empty Response" Error
- Check network connection
- Verify Anthropic API is accessible
- Check API quota/billing

### AI Gives Generic Responses
- Make sure transactions are loaded: `viewModel.setTransactions()`
- Check transaction data is not empty
- Verify system prompt includes transaction data

### Chat Is Slow
- Normal: AI responses take 2-5 seconds
- Check network speed
- Consider using Claude Haiku for faster responses

## API Costs

Anthropic Claude 3.5 Sonnet pricing (as of Jan 2026):
- Input: $3 per million tokens
- Output: $15 per million tokens

Typical usage:
- ~1500 tokens per question (input + output)
- ~$0.003 per message
- 100 messages ≈ $0.30

## Security Notes

🔒 **API Key**: Store securely, never commit to version control  
🔒 **User Data**: Sent to Anthropic for processing  
🔒 **Network**: All requests use HTTPS  
🔒 **Storage**: Conversations not persisted to disk  

## Support

For issues or questions:
1. Check this documentation
2. Review console logs for errors
3. Verify API key and network connectivity
4. Check Anthropic API status page

---

**Created**: January 19, 2026  
**Last Updated**: January 19, 2026  
**Version**: 1.0
