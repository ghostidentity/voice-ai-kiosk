using System.IO.Pipes;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace OrderUpdateListener
{
    public class OrderConfirmation
    {
        [JsonPropertyName("order_id")]
        public string OrderId { get; set; }
        
        [JsonPropertyName("payment_method")]
        public string PaymentMethod { get; set; }
        
        [JsonPropertyName("user_session_id")]
        public string UserSessionId { get; set; }
        
        [JsonPropertyName("items")]
        public OrderItem[] Items { get; set; }
        
        [JsonPropertyName("total_amount")]
        public double TotalAmount { get; set; }
        
        [JsonPropertyName("message")]
        public string Message { get; set; }
        
        [JsonPropertyName("timestamp")]
        public string Timestamp { get; set; }
    }

    public class OrderItem
    {
        [JsonPropertyName("product_id")]
        public string ProductId { get; set; }
        
        [JsonPropertyName("product_name")]
        public string ProductName { get; set; }
        
        [JsonPropertyName("quantity")]
        public int Quantity { get; set; }
        
        [JsonPropertyName("price")]
        public double Price { get; set; }
    }

    class Program
    {
        const string PipeName = "KioskOrderConfirmation";
        private static bool isConnected = false;
        private static int connectionAttempts = 0;
        private static int ordersReceived = 0;
        private static DateTime? firstConnectionTime = null;

        static async Task Main(string[] args)
        {
            Console.Title = "Order Confirmation Listener";
            Console.WriteLine("========================================");
            Console.WriteLine("     ORDER CONFIRMATION LISTENER");
            Console.WriteLine("========================================");
            Console.WriteLine($"Pipe: {PipeName}");
            Console.WriteLine($"Started: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
            Console.WriteLine("Status: Waiting for Go server...");
            Console.WriteLine("========================================\n");

            while (true)
            {
                try
                {
                    using (var client = new NamedPipeClientStream(".", PipeName, PipeDirection.In))
                    {
                        // Silent connection attempt
                        connectionAttempts++;
                        
                        if (!isConnected && connectionAttempts % 5 == 0)
                        {
                            // Only show retry message every 5 attempts when not connected
                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Still waiting for Go server... (attempt {connectionAttempts})");
                        }
                        
                        await client.ConnectAsync(5000);
                        
                        // Connection successful
                        if (!isConnected)
                        {
                            isConnected = true;
                            firstConnectionTime = DateTime.Now;
                            Console.WriteLine($"\n[{DateTime.Now:HH:mm:ss}] ✅ CONNECTED to Go server!");
                            Console.WriteLine("Ready to receive order confirmations...\n");
                        }
                        
                        using (var reader = new StreamReader(client, Encoding.UTF8))
                        {
                            while (client.IsConnected)
                            {
                                try
                                {
                                    string message = await reader.ReadLineAsync();
                                    
                                    if (!string.IsNullOrEmpty(message))
                                    {
                                        ordersReceived++;
                                        ProcessOrderConfirmation(message, ordersReceived);
                                    }
                                }
                                catch (IOException)
                                {
                                    // Connection lost
                                    if (isConnected)
                                    {
                                        isConnected = false;
                                        Console.WriteLine($"\n[{DateTime.Now:HH:mm:ss}] ⚠️  Connection lost. Reconnecting...");
                                    }
                                    break;
                                }
                                catch (Exception ex)
                                {
                                    Console.WriteLine($"\n[{DateTime.Now:HH:mm:ss}] Error reading: {ex.Message}");
                                    break;
                                }
                            }
                        }
                    }
                }
                catch (TimeoutException)
                {
                    // Silent timeout - don't print anything
                }
                catch (Exception ex)
                {
                    // Only show unexpected errors
                    if (!ex.Message.Contains("timeout", StringComparison.OrdinalIgnoreCase))
                    {
                        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Error: {ex.Message}");
                    }
                }

                // Brief pause before reconnection
                await Task.Delay(1000);
            }
        }

        static void ProcessOrderConfirmation(string jsonData, int orderNumber)
        {
            try
            {
                var options = new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                };
                
                var order = JsonSerializer.Deserialize<OrderConfirmation>(jsonData, options);
                
                // Show order notification
                Console.WriteLine($"\n[{DateTime.Now:HH:mm:ss}] 📦 NEW ORDER #{orderNumber}");
                Console.WriteLine($"    ID: {order.OrderId}");
                Console.WriteLine($"    Payment: {order.PaymentMethod}");
                Console.WriteLine($"    Total: ${order.TotalAmount:F2}");
                Console.WriteLine($"    Items: {order.Items?.Length ?? 0}");
                
                // Optional: Show detailed view on request or for first few orders
                if (orderNumber <= 3 || orderNumber % 5 == 0)
                {
                    ShowOrderDetails(order);
                }
            }
            catch (JsonException ex)
            {
                Console.WriteLine($"\n[{DateTime.Now:HH:mm:ss}] ❌ JSON Error: {ex.Message}");
                Console.WriteLine($"Data (first 200 chars): {jsonData.Substring(0, Math.Min(jsonData.Length, 200))}");
            }
        }

        static void ShowOrderDetails(OrderConfirmation order)
        {
            Console.WriteLine("    ┌─────────────────────────────────────────────┐");
            Console.WriteLine($"    │ Order Details                              │");
            Console.WriteLine($"    │ User: {order.UserSessionId,-30} │");
            Console.WriteLine($"    │ Time: {order.Timestamp,-30} │");
            Console.WriteLine($"    │ Message: {order.Message,-28} │");
            Console.WriteLine($"    └─────────────────────────────────────────────┘");
            
            if (order.Items != null && order.Items.Length > 0)
            {
                Console.WriteLine("    Items:");
                foreach (var item in order.Items)
                {
                    Console.WriteLine($"      • {item.ProductName} (x{item.Quantity}) @ ${item.Price:F2}");
                }
            }
        }
    }
}