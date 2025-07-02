// AI-Generated Code Header
// **Intent:** Demonstrate modern Android development with Kotlin, Compose, and MVVM
// **Optimization:** Efficient state management, lifecycle-aware components, and UI composition
// **Safety:** Proper memory management, exception handling, and thread safety

package com.example.android

import android.app.Application
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.*
import androidx.navigation.NavController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.text.NumberFormat
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.*

// AI-SUGGESTION: Data models for the shopping list app
data class ShoppingItem(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val quantity: Int = 1,
    val price: Double = 0.0,
    val category: ItemCategory = ItemCategory.OTHER,
    val isPurchased: Boolean = false,
    val createdAt: LocalDateTime = LocalDateTime.now(),
    val notes: String? = null
) {
    val totalPrice: Double get() = quantity * price
}

enum class ItemCategory(val displayName: String, val color: Color) {
    FOOD("Food", Color(0xFF4CAF50)),
    HOUSEHOLD("Household", Color(0xFF2196F3)),
    ELECTRONICS("Electronics", Color(0xFF9C27B0)),
    CLOTHING("Clothing", Color(0xFFFF9800)),
    HEALTH("Health", Color(0xFFF44336)),
    OTHER("Other", Color(0xFF607D8B))
}

data class ShoppingList(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val items: List<ShoppingItem> = emptyList(),
    val isCompleted: Boolean = false,
    val createdAt: LocalDateTime = LocalDateTime.now()
) {
    val totalCost: Double get() = items.sumOf { it.totalPrice }
    val itemCount: Int get() = items.size
    val purchasedCount: Int get() = items.count { it.isPurchased }
    val completionPercentage: Float get() = if (items.isEmpty()) 0f else purchasedCount.toFloat() / items.size
}

// AI-SUGGESTION: Repository for data management
interface ShoppingRepository {
    fun getAllLists(): Flow<List<ShoppingList>>
    suspend fun getListById(id: String): ShoppingList?
    suspend fun createList(list: ShoppingList): ShoppingList
    suspend fun updateList(list: ShoppingList): ShoppingList
    suspend fun deleteList(id: String): Boolean
    suspend fun addItemToList(listId: String, item: ShoppingItem): Boolean
    suspend fun updateItem(listId: String, item: ShoppingItem): Boolean
    suspend fun deleteItem(listId: String, itemId: String): Boolean
}

// AI-SUGGESTION: In-memory repository implementation
class InMemoryShoppingRepository : ShoppingRepository {
    private val _lists = MutableStateFlow<List<ShoppingList>>(
        listOf(
            ShoppingList(
                name = "Grocery Shopping",
                items = listOf(
                    ShoppingItem(name = "Milk", quantity = 2, price = 3.99, category = ItemCategory.FOOD),
                    ShoppingItem(name = "Bread", quantity = 1, price = 2.49, category = ItemCategory.FOOD, isPurchased = true),
                    ShoppingItem(name = "Smartphone", quantity = 1, price = 599.99, category = ItemCategory.ELECTRONICS)
                )
            ),
            ShoppingList(
                name = "Weekly Essentials",
                items = listOf(
                    ShoppingItem(name = "Toothpaste", quantity = 1, price = 4.99, category = ItemCategory.HEALTH),
                    ShoppingItem(name = "Laundry Detergent", quantity = 1, price = 12.99, category = ItemCategory.HOUSEHOLD)
                )
            )
        )
    )
    
    override fun getAllLists(): Flow<List<ShoppingList>> = _lists.asStateFlow()
    
    override suspend fun getListById(id: String): ShoppingList? {
        return _lists.value.find { it.id == id }
    }
    
    override suspend fun createList(list: ShoppingList): ShoppingList {
        _lists.value = _lists.value + list
        return list
    }
    
    override suspend fun updateList(list: ShoppingList): ShoppingList {
        _lists.value = _lists.value.map { if (it.id == list.id) list else it }
        return list
    }
    
    override suspend fun deleteList(id: String): Boolean {
        val originalSize = _lists.value.size
        _lists.value = _lists.value.filter { it.id != id }
        return _lists.value.size < originalSize
    }
    
    override suspend fun addItemToList(listId: String, item: ShoppingItem): Boolean {
        val list = getListById(listId) ?: return false
        val updatedList = list.copy(items = list.items + item)
        updateList(updatedList)
        return true
    }
    
    override suspend fun updateItem(listId: String, item: ShoppingItem): Boolean {
        val list = getListById(listId) ?: return false
        val updatedItems = list.items.map { if (it.id == item.id) item else it }
        val updatedList = list.copy(items = updatedItems)
        updateList(updatedList)
        return true
    }
    
    override suspend fun deleteItem(listId: String, itemId: String): Boolean {
        val list = getListById(listId) ?: return false
        val updatedItems = list.items.filter { it.id != itemId }
        val updatedList = list.copy(items = updatedItems)
        updateList(updatedList)
        return true
    }
}

// AI-SUGGESTION: ViewModel for managing UI state
class ShoppingListViewModel(
    private val repository: ShoppingRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(ShoppingUiState())
    val uiState: StateFlow<ShoppingUiState> = _uiState.asStateFlow()
    
    private val _selectedListId = MutableStateFlow<String?>(null)
    val selectedListId: StateFlow<String?> = _selectedListId.asStateFlow()
    
    val allLists = repository.getAllLists()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )
    
    val selectedList = combine(allLists, selectedListId) { lists, selectedId ->
        selectedId?.let { id -> lists.find { it.id == id } }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = null
    )
    
    fun selectList(listId: String) {
        _selectedListId.value = listId
    }
    
    fun createNewList(name: String) {
        if (name.isBlank()) {
            updateUiState { it.copy(error = "List name cannot be empty") }
            return
        }
        
        viewModelScope.launch {
            try {
                val newList = ShoppingList(name = name.trim())
                repository.createList(newList)
                updateUiState { it.copy(isLoading = false, error = null) }
            } catch (e: Exception) {
                updateUiState { it.copy(isLoading = false, error = "Failed to create list: ${e.message}") }
            }
        }
    }
    
    fun addItemToList(listId: String, itemName: String, quantity: Int, price: Double, category: ItemCategory) {
        if (itemName.isBlank()) {
            updateUiState { it.copy(error = "Item name cannot be empty") }
            return
        }
        
        viewModelScope.launch {
            try {
                val newItem = ShoppingItem(
                    name = itemName.trim(),
                    quantity = quantity.coerceAtLeast(1),
                    price = price.coerceAtLeast(0.0),
                    category = category
                )
                repository.addItemToList(listId, newItem)
                updateUiState { it.copy(isLoading = false, error = null) }
            } catch (e: Exception) {
                updateUiState { it.copy(isLoading = false, error = "Failed to add item: ${e.message}") }
            }
        }
    }
    
    fun toggleItemPurchased(listId: String, item: ShoppingItem) {
        viewModelScope.launch {
            try {
                val updatedItem = item.copy(isPurchased = !item.isPurchased)
                repository.updateItem(listId, updatedItem)
            } catch (e: Exception) {
                updateUiState { it.copy(error = "Failed to update item: ${e.message}") }
            }
        }
    }
    
    fun deleteItem(listId: String, itemId: String) {
        viewModelScope.launch {
            try {
                repository.deleteItem(listId, itemId)
            } catch (e: Exception) {
                updateUiState { it.copy(error = "Failed to delete item: ${e.message}") }
            }
        }
    }
    
    fun clearError() {
        updateUiState { it.copy(error = null) }
    }
    
    private fun updateUiState(update: (ShoppingUiState) -> ShoppingUiState) {
        _uiState.value = update(_uiState.value)
    }
}

data class ShoppingUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val showAddItemDialog: Boolean = false,
    val showAddListDialog: Boolean = false
)

// AI-SUGGESTION: ViewModelFactory for dependency injection
class ShoppingViewModelFactory(
    private val repository: ShoppingRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(ShoppingListViewModel::class.java)) {
            return ShoppingListViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}

// AI-SUGGESTION: Application class for dependency injection setup
class ShoppingApplication : Application() {
    val repository: ShoppingRepository by lazy { InMemoryShoppingRepository() }
}

// AI-SUGGESTION: Main Activity
class MainActivity : ComponentActivity() {
    private lateinit var viewModel: ShoppingListViewModel
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val application = application as ShoppingApplication
        val factory = ShoppingViewModelFactory(application.repository)
        viewModel = ViewModelProvider(this, factory)[ShoppingListViewModel::class.java]
        
        setContent {
            ShoppingAppTheme {
                ShoppingApp(viewModel)
            }
        }
    }
}

// AI-SUGGESTION: Main app composable with navigation
@Composable
fun ShoppingApp(viewModel: ShoppingListViewModel) {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = "lists"
    ) {
        composable("lists") {
            ShoppingListsScreen(
                viewModel = viewModel,
                onListSelected = { listId ->
                    viewModel.selectList(listId)
                    navController.navigate("list_detail")
                }
            )
        }
        composable("list_detail") {
            ShoppingListDetailScreen(
                viewModel = viewModel,
                onBackPressed = { navController.popBackStack() }
            )
        }
    }
}

// AI-SUGGESTION: Shopping lists overview screen
@Composable
fun ShoppingListsScreen(
    viewModel: ShoppingListViewModel,
    onListSelected: (String) -> Unit
) {
    val lists by viewModel.allLists.collectAsState()
    val uiState by viewModel.uiState.collectAsState()
    var showAddDialog by rememberSaveable { mutableStateOf(false) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Shopping Lists") },
                actions = {
                    IconButton(onClick = { showAddDialog = true }) {
                        Icon(Icons.Default.Add, contentDescription = "Add List")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (lists.isEmpty()) {
                EmptyStateMessage(
                    message = "No shopping lists yet",
                    action = "Create your first list",
                    onActionClick = { showAddDialog = true }
                )
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(lists) { list ->
                        ShoppingListCard(
                            list = list,
                            onClick = { onListSelected(list.id) }
                        )
                    }
                }
            }
        }
    }
    
    if (showAddDialog) {
        AddListDialog(
            onDismiss = { showAddDialog = false },
            onConfirm = { name ->
                viewModel.createNewList(name)
                showAddDialog = false
            }
        )
    }
    
    uiState.error?.let { error ->
        LaunchedEffect(error) {
            // Show snackbar or handle error
            viewModel.clearError()
        }
    }
}

// AI-SUGGESTION: Shopping list card component
@Composable
fun ShoppingListCard(
    list: ShoppingList,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(120.dp),
        elevation = 4.dp,
        shape = RoundedCornerShape(12.dp),
        onClick = onClick
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = list.name,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = NumberFormat.getCurrencyInstance().format(list.totalCost),
                    fontSize = 16.sp,
                    color = MaterialTheme.colors.primary
                )
            }
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${list.purchasedCount}/${list.itemCount} items",
                    fontSize = 14.sp,
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f)
                )
                LinearProgressIndicator(
                    progress = list.completionPercentage,
                    modifier = Modifier.width(100.dp)
                )
            }
        }
    }
}

// AI-SUGGESTION: Shopping list detail screen
@Composable
fun ShoppingListDetailScreen(
    viewModel: ShoppingListViewModel,
    onBackPressed: () -> Unit
) {
    val list by viewModel.selectedList.collectAsState()
    var showAddItemDialog by rememberSaveable { mutableStateOf(false) }
    
    list?.let { shoppingList ->
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(shoppingList.name) },
                    navigationIcon = {
                        IconButton(onClick = onBackPressed) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                        }
                    },
                    actions = {
                        IconButton(onClick = { showAddItemDialog = true }) {
                            Icon(Icons.Default.Add, contentDescription = "Add Item")
                        }
                    }
                )
            }
        ) { paddingValues ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                // List summary
                ListSummaryCard(list = shoppingList)
                
                // Items list
                if (shoppingList.items.isEmpty()) {
                    EmptyStateMessage(
                        message = "No items in this list",
                        action = "Add your first item",
                        onActionClick = { showAddItemDialog = true }
                    )
                } else {
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(shoppingList.items) { item ->
                            ShoppingItemCard(
                                item = item,
                                onTogglePurchased = { 
                                    viewModel.toggleItemPurchased(shoppingList.id, item) 
                                },
                                onDelete = { 
                                    viewModel.deleteItem(shoppingList.id, item.id) 
                                }
                            )
                        }
                    }
                }
            }
        }
        
        if (showAddItemDialog) {
            AddItemDialog(
                onDismiss = { showAddItemDialog = false },
                onConfirm = { name, quantity, price, category ->
                    viewModel.addItemToList(shoppingList.id, name, quantity, price, category)
                    showAddItemDialog = false
                }
            )
        }
    } ?: run {
        // Handle case where list is not found
        LaunchedEffect(Unit) {
            onBackPressed()
        }
    }
}

// AI-SUGGESTION: Shopping item card component
@Composable
fun ShoppingItemCard(
    item: ShoppingItem,
    onTogglePurchased: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = 2.dp,
        backgroundColor = if (item.isPurchased) 
            MaterialTheme.colors.surface.copy(alpha = 0.7f) 
        else MaterialTheme.colors.surface
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(
                checked = item.isPurchased,
                onCheckedChange = { onTogglePurchased() }
            )
            
            Spacer(modifier = Modifier.width(12.dp))
            
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(item.category.color)
            )
            
            Spacer(modifier = Modifier.width(12.dp))
            
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.name,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (item.isPurchased) 
                        MaterialTheme.colors.onSurface.copy(alpha = 0.6f)
                    else MaterialTheme.colors.onSurface
                )
                Text(
                    text = "${item.quantity} × ${NumberFormat.getCurrencyInstance().format(item.price)}",
                    fontSize = 14.sp,
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f)
                )
            }
            
            Text(
                text = NumberFormat.getCurrencyInstance().format(item.totalPrice),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colors.primary
            )
            
            IconButton(onClick = onDelete) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = MaterialTheme.colors.error
                )
            }
        }
    }
}

// AI-SUGGESTION: Empty state component
@Composable
fun EmptyStateMessage(
    message: String,
    action: String,
    onActionClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.ShoppingCart,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colors.onSurface.copy(alpha = 0.3f)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = message,
            fontSize = 18.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onActionClick) {
            Text(action)
        }
    }
}

// AI-SUGGESTION: Add list dialog
@Composable
fun AddListDialog(
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var listName by rememberSaveable { mutableStateOf("") }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create New List") },
        text = {
            OutlinedTextField(
                value = listName,
                onValueChange = { listName = it },
                label = { Text("List Name") },
                singleLine = true
            )
        },
        confirmButton = {
            TextButton(
                onClick = { onConfirm(listName) },
                enabled = listName.isNotBlank()
            ) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

// AI-SUGGESTION: Add item dialog
@Composable
fun AddItemDialog(
    onDismiss: () -> Unit,
    onConfirm: (String, Int, Double, ItemCategory) -> Unit
) {
    var itemName by rememberSaveable { mutableStateOf("") }
    var quantity by rememberSaveable { mutableStateOf("1") }
    var price by rememberSaveable { mutableStateOf("") }
    var selectedCategory by rememberSaveable { mutableStateOf(ItemCategory.OTHER) }
    var showCategoryDropdown by rememberSaveable { mutableStateOf(false) }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Item") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = itemName,
                    onValueChange = { itemName = it },
                    label = { Text("Item Name") },
                    singleLine = true
                )
                
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = quantity,
                        onValueChange = { quantity = it },
                        label = { Text("Quantity") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                    
                    OutlinedTextField(
                        value = price,
                        onValueChange = { price = it },
                        label = { Text("Price") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        modifier = Modifier.weight(1f)
                    )
                }
                
                Box {
                    OutlinedTextField(
                        value = selectedCategory.displayName,
                        onValueChange = { },
                        label = { Text("Category") },
                        readOnly = true,
                        trailingIcon = {
                            IconButton(onClick = { showCategoryDropdown = true }) {
                                Icon(Icons.Default.ArrowDropDown, contentDescription = "Select Category")
                            }
                        }
                    )
                    
                    DropdownMenu(
                        expanded = showCategoryDropdown,
                        onDismissRequest = { showCategoryDropdown = false }
                    ) {
                        ItemCategory.values().forEach { category ->
                            DropdownMenuItem(
                                onClick = {
                                    selectedCategory = category
                                    showCategoryDropdown = false
                                }
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(16.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(category.color)
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(category.displayName)
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val qty = quantity.toIntOrNull() ?: 1
                    val prc = price.toDoubleOrNull() ?: 0.0
                    onConfirm(itemName, qty, prc, selectedCategory)
                },
                enabled = itemName.isNotBlank()
            ) {
                Text("Add")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

// AI-SUGGESTION: List summary card
@Composable
fun ListSummaryCard(list: ShoppingList) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        elevation = 4.dp
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Total Items", fontWeight = FontWeight.Medium)
                Text("${list.itemCount}")
            }
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Purchased", fontWeight = FontWeight.Medium)
                Text("${list.purchasedCount}")
            }
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Total Cost", fontWeight = FontWeight.Medium)
                Text(
                    NumberFormat.getCurrencyInstance().format(list.totalCost),
                    color = MaterialTheme.colors.primary,
                    fontWeight = FontWeight.Bold
                )
            }
            
            LinearProgressIndicator(
                progress = list.completionPercentage,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

// AI-SUGGESTION: Theme setup
@Composable
fun ShoppingAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colors = lightColors(
            primary = Color(0xFF6200EE),
            primaryVariant = Color(0xFF3700B3),
            secondary = Color(0xFF03DAC6)
        ),
        content = content
    )
}

// AI-SUGGESTION: Preview composables for development
@Preview(showBackground = true)
@Composable
fun ShoppingListCardPreview() {
    ShoppingAppTheme {
        ShoppingListCard(
            list = ShoppingList(
                name = "Weekly Groceries",
                items = listOf(
                    ShoppingItem("Milk", 2, 3.99, ItemCategory.FOOD),
                    ShoppingItem("Bread", 1, 2.49, ItemCategory.FOOD, isPurchased = true)
                )
            ),
            onClick = {}
        )
    }
} 