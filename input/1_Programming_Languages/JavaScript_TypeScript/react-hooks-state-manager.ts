// AI-Generated Code Header
// **Intent:** React-style hooks and state management system with TypeScript
// **Optimization:** Efficient state updates and memory management
// **Safety:** Type-safe hooks with proper cleanup and error handling

// AI-SUGGESTION: Hook types and interfaces
type Dispatch<T> = (value: T | ((prev: T) => T)) => void;
type EffectCallback = () => void | (() => void);
type DependencyList = ReadonlyArray<any>;

interface Hook {
    cleanup?: () => void;
}

interface StateHook<T> extends Hook {
    state: T;
    setState: Dispatch<T>;
}

interface EffectHook extends Hook {
    effect: EffectCallback;
    deps?: DependencyList;
    cleanup?: () => void;
}

interface RefHook<T> extends Hook {
    current: T;
}

// AI-SUGGESTION: Hook execution context
class HookContext {
    private hooks: Hook[] = [];
    private currentHookIndex = 0;
    private isRendering = false;

    startRender(): void {
        this.isRendering = true;
        this.currentHookIndex = 0;
    }

    endRender(): void {
        this.isRendering = false;
    }

    getNextHook<T extends Hook>(): T | null {
        if (!this.isRendering) {
            throw new Error('Hooks can only be called during render');
        }
        return this.hooks[this.currentHookIndex++] as T || null;
    }

    addHook<T extends Hook>(hook: T): T {
        if (!this.isRendering) {
            throw new Error('Hooks can only be called during render');
        }
        this.hooks[this.currentHookIndex++] = hook;
        return hook;
    }

    cleanup(): void {
        this.hooks.forEach(hook => {
            if (hook.cleanup) {
                hook.cleanup();
            }
        });
        this.hooks = [];
        this.currentHookIndex = 0;
    }
}

// AI-SUGGESTION: Global hook context
let currentContext: HookContext | null = null;

function getCurrentContext(): HookContext {
    if (!currentContext) {
        throw new Error('No hook context available');
    }
    return currentContext;
}

// AI-SUGGESTION: useState hook implementation
function useState<T>(initialState: T | (() => T)): [T, Dispatch<T>] {
    const context = getCurrentContext();
    let hook = context.getNextHook<StateHook<T>>();

    if (!hook) {
        const initialValue = typeof initialState === 'function' 
            ? (initialState as () => T)() 
            : initialState;

        hook = context.addHook<StateHook<T>>({
            state: initialValue,
            setState: (value: T | ((prev: T) => T)) => {
                const newValue = typeof value === 'function'
                    ? (value as (prev: T) => T)(hook!.state)
                    : value;
                
                if (Object.is(hook!.state, newValue)) return;
                
                hook!.state = newValue;
                // Trigger re-render (simplified)
                setTimeout(() => triggerUpdate(), 0);
            }
        });
    }

    return [hook.state, hook.setState];
}

// AI-SUGGESTION: useEffect hook implementation
function useEffect(effect: EffectCallback, deps?: DependencyList): void {
    const context = getCurrentContext();
    let hook = context.getNextHook<EffectHook>();

    if (!hook) {
        hook = context.addHook<EffectHook>({
            effect,
            deps: deps ? [...deps] : undefined,
            cleanup: undefined
        });
    }

    const depsChanged = !hook.deps || !deps || 
        hook.deps.length !== deps.length ||
        hook.deps.some((dep, index) => !Object.is(dep, deps[index]));

    if (depsChanged) {
        if (hook.cleanup) {
            hook.cleanup();
        }

        hook.deps = deps ? [...deps] : undefined;
        
        // Execute effect asynchronously
        setTimeout(() => {
            const cleanup = hook!.effect();
            if (typeof cleanup === 'function') {
                hook!.cleanup = cleanup;
            }
        }, 0);
    }
}

// AI-SUGGESTION: useRef hook implementation
function useRef<T>(initialValue: T): { current: T } {
    const context = getCurrentContext();
    let hook = context.getNextHook<RefHook<T>>();

    if (!hook) {
        hook = context.addHook<RefHook<T>>({
            current: initialValue
        });
    }

    return hook;
}

// AI-SUGGESTION: Custom hooks
function useLocalStorage<T>(key: string, initialValue: T): [T, Dispatch<T>] {
    const [storedValue, setStoredValue] = useState<T>(() => {
        try {
            const item = localStorage.getItem(key);
            return item ? JSON.parse(item) : initialValue;
        } catch (error) {
            console.error(`Error reading localStorage key "${key}":`, error);
            return initialValue;
        }
    });

    const setValue: Dispatch<T> = (value) => {
        try {
            const valueToStore = typeof value === 'function' 
                ? (value as (prev: T) => T)(storedValue)
                : value;

            setStoredValue(valueToStore);
            localStorage.setItem(key, JSON.stringify(valueToStore));
        } catch (error) {
            console.error(`Error setting localStorage key "${key}":`, error);
        }
    };

    return [storedValue, setValue];
}

function useCounter(initialValue: number = 0) {
    const [count, setCount] = useState(initialValue);

    const increment = () => setCount(prev => prev + 1);
    const decrement = () => setCount(prev => prev - 1);
    const reset = () => setCount(initialValue);
    const set = (value: number) => setCount(value);

    return { count, increment, decrement, reset, set };
}

function useToggle(initialValue: boolean = false) {
    const [value, setValue] = useState(initialValue);

    const toggle = () => setValue(prev => !prev);
    const setTrue = () => setValue(true);
    const setFalse = () => setValue(false);

    return { value, toggle, setTrue, setFalse };
}

// AI-SUGGESTION: State management with reducers
type Action<T = any> = {
    type: string;
    payload?: T;
};

type Reducer<S, A extends Action> = (state: S, action: A) => S;

function useReducer<S, A extends Action>(
    reducer: Reducer<S, A>,
    initialState: S
): [S, (action: A) => void] {
    const [state, setState] = useState(initialState);

    const dispatch = (action: A) => {
        setState(prevState => reducer(prevState, action));
    };

    return [state, dispatch];
}

// AI-SUGGESTION: Advanced state management with context
interface StateContextValue<T> {
    state: T;
    dispatch: (action: Action) => void;
}

class StateProvider<T> {
    private subscribers: Array<() => void> = [];
    private state: T;
    private reducer: Reducer<T, Action>;

    constructor(reducer: Reducer<T, Action>, initialState: T) {
        this.reducer = reducer;
        this.state = initialState;
    }

    getState(): T {
        return this.state;
    }

    dispatch(action: Action): void {
        const newState = this.reducer(this.state, action);
        if (this.state !== newState) {
            this.state = newState;
            this.subscribers.forEach(callback => callback());
        }
    }

    subscribe(callback: () => void): () => void {
        this.subscribers.push(callback);
        return () => {
            const index = this.subscribers.indexOf(callback);
            if (index > -1) {
                this.subscribers.splice(index, 1);
            }
        };
    }
}

function useStateProvider<T>(provider: StateProvider<T>): StateContextValue<T> {
    const [state, setState] = useState(provider.getState());

    useEffect(() => {
        const unsubscribe = provider.subscribe(() => {
            setState(provider.getState());
        });
        return unsubscribe;
    }, [provider]);

    return {
        state,
        dispatch: provider.dispatch.bind(provider)
    };
}

// AI-SUGGESTION: Component-like function with hooks
interface ComponentProps {
    [key: string]: any;
}

type Component<P extends ComponentProps = {}> = (props: P) => void;

function createComponent<P extends ComponentProps>(
    render: (props: P) => void
): Component<P> {
    return function(props: P) {
        const context = new HookContext();
        currentContext = context;

        try {
            context.startRender();
            render(props);
            context.endRender();
        } catch (error) {
            console.error('Component render error:', error);
        } finally {
            currentContext = null;
        }
    };
}

// AI-SUGGESTION: Application state types
interface User {
    id: string;
    name: string;
    email: string;
    preferences: {
        theme: 'light' | 'dark';
        notifications: boolean;
    };
}

interface AppState {
    user: User | null;
    loading: boolean;
    error: string | null;
    todos: Todo[];
}

interface Todo {
    id: string;
    text: string;
    completed: boolean;
    createdAt: Date;
}

// AI-SUGGESTION: Action types
type AppAction =
    | { type: 'SET_USER'; payload: User }
    | { type: 'SET_LOADING'; payload: boolean }
    | { type: 'SET_ERROR'; payload: string | null }
    | { type: 'ADD_TODO'; payload: Omit<Todo, 'id'> }
    | { type: 'TOGGLE_TODO'; payload: string }
    | { type: 'DELETE_TODO'; payload: string }
    | { type: 'CLEAR_COMPLETED' };

// AI-SUGGESTION: App reducer
function appReducer(state: AppState, action: AppAction): AppState {
    switch (action.type) {
        case 'SET_USER':
            return { ...state, user: action.payload, error: null };
        
        case 'SET_LOADING':
            return { ...state, loading: action.payload };
        
        case 'SET_ERROR':
            return { ...state, error: action.payload, loading: false };
        
        case 'ADD_TODO':
            const newTodo: Todo = {
                ...action.payload,
                id: Date.now().toString(),
                createdAt: new Date()
            };
            return { ...state, todos: [...state.todos, newTodo] };
        
        case 'TOGGLE_TODO':
            return {
                ...state,
                todos: state.todos.map(todo =>
                    todo.id === action.payload
                        ? { ...todo, completed: !todo.completed }
                        : todo
                )
            };
        
        case 'DELETE_TODO':
            return {
                ...state,
                todos: state.todos.filter(todo => todo.id !== action.payload)
            };
        
        case 'CLEAR_COMPLETED':
            return {
                ...state,
                todos: state.todos.filter(todo => !todo.completed)
            };
        
        default:
            return state;
    }
}

// AI-SUGGESTION: Demo application
let updateCallbacks: Array<() => void> = [];

function triggerUpdate() {
    updateCallbacks.forEach(callback => callback());
}

const TodoApp = createComponent<{}>(() => {
    const [state, dispatch] = useReducer(appReducer, {
        user: null,
        loading: false,
        error: null,
        todos: []
    });

    const [newTodoText, setNewTodoText] = useState('');
    const { value: showCompleted, toggle: toggleShowCompleted } = useToggle(true);
    const counter = useCounter(0);

    // Load user from localStorage
    useEffect(() => {
        const savedUser = localStorage.getItem('user');
        if (savedUser) {
            try {
                const user = JSON.parse(savedUser);
                dispatch({ type: 'SET_USER', payload: user });
            } catch (error) {
                console.error('Error loading user from localStorage:', error);
            }
        }
    }, []);

    // Save user to localStorage when it changes
    useEffect(() => {
        if (state.user) {
            localStorage.setItem('user', JSON.stringify(state.user));
        }
    }, [state.user]);

    const addTodo = () => {
        if (newTodoText.trim()) {
            dispatch({
                type: 'ADD_TODO',
                payload: {
                    text: newTodoText.trim(),
                    completed: false,
                    createdAt: new Date()
                }
            });
            setNewTodoText('');
            counter.increment();
        }
    };

    const simulateLogin = () => {
        dispatch({ type: 'SET_LOADING', payload: true });
        
        setTimeout(() => {
            const user: User = {
                id: '1',
                name: 'John Doe',
                email: 'john@example.com',
                preferences: {
                    theme: 'light',
                    notifications: true
                }
            };
            dispatch({ type: 'SET_USER', payload: user });
            dispatch({ type: 'SET_LOADING', payload: false });
        }, 1000);
    };

    // Display app state (simplified for demo)
    console.log('--- Todo App State ---');
    console.log('User:', state.user?.name || 'Not logged in');
    console.log('Loading:', state.loading);
    console.log('Todos count:', state.todos.length);
    console.log('Show completed:', showCompleted);
    console.log('Counter:', counter.count);
    
    const activeTodos = state.todos.filter(todo => !todo.completed);
    const completedTodos = state.todos.filter(todo => todo.completed);
    console.log('Active todos:', activeTodos.length);
    console.log('Completed todos:', completedTodos.length);

    return {
        state,
        actions: {
            addTodo,
            toggleShowCompleted,
            simulateLogin,
            toggleTodo: (id: string) => dispatch({ type: 'TOGGLE_TODO', payload: id }),
            deleteTodo: (id: string) => dispatch({ type: 'DELETE_TODO', payload: id }),
            clearCompleted: () => dispatch({ type: 'CLEAR_COMPLETED' })
        }
    };
});

// AI-SUGGESTION: App provider and demo
class AppProvider {
    private stateProvider: StateProvider<AppState>;
    private todoApp: any;

    constructor() {
        const initialState: AppState = {
            user: null,
            loading: false,
            error: null,
            todos: []
        };

        this.stateProvider = new StateProvider(appReducer, initialState);
        this.todoApp = null;
    }

    render() {
        this.todoApp = TodoApp({});
        return this.todoApp;
    }

    getState() {
        return this.stateProvider.getState();
    }

    dispatch(action: AppAction) {
        this.stateProvider.dispatch(action);
    }
}

// AI-SUGGESTION: Demo function
async function demonstrateReactHooks(): Promise<void> {
    console.log('⚛️  React-style Hooks and State Management Demo');
    console.log('===============================================');

    const app = new AppProvider();

    console.log('\n--- Initial Render ---');
    const todoApp = app.render();

    // Simulate user interactions
    console.log('\n--- User Login ---');
    if (todoApp && todoApp.actions) {
        todoApp.actions.simulateLogin();
    }

    // Wait for async login
    await new Promise(resolve => setTimeout(resolve, 1100));

    console.log('\n--- Adding Todos ---');
    if (todoApp && todoApp.actions) {
        // Simulate adding todos (would need to re-render to see state changes)
        app.dispatch({ 
            type: 'ADD_TODO', 
            payload: { text: 'Learn TypeScript', completed: false, createdAt: new Date() } 
        });
        
        app.dispatch({ 
            type: 'ADD_TODO', 
            payload: { text: 'Build React app', completed: false, createdAt: new Date() } 
        });
        
        app.dispatch({ 
            type: 'ADD_TODO', 
            payload: { text: 'Write tests', completed: false, createdAt: new Date() } 
        });
    }

    console.log('\n--- Final State ---');
    console.log('App state:', app.getState());

    console.log('\n--- Toggle Todos ---');
    const currentState = app.getState();
    if (currentState.todos.length > 0) {
        app.dispatch({ type: 'TOGGLE_TODO', payload: currentState.todos[0].id });
        console.log('Toggled first todo');
    }

    console.log('\n--- Clear Completed ---');
    app.dispatch({ type: 'CLEAR_COMPLETED' });
    console.log('Cleared completed todos');

    console.log('\n--- Final App State ---');
    console.log(app.getState());

    console.log('\n=== React Hooks Demo Complete ===');
}

// AI-SUGGESTION: Export hooks and utilities
export {
    useState,
    useEffect,
    useRef,
    useReducer,
    useLocalStorage,
    useCounter,
    useToggle,
    useStateProvider,
    createComponent,
    StateProvider,
    TodoApp,
    AppProvider,
    demonstrateReactHooks
};

export type {
    Dispatch,
    EffectCallback,
    DependencyList,
    Component,
    ComponentProps,
    AppState,
    AppAction,
    User,
    Todo
};

// Run demo if executed directly
if (typeof require !== 'undefined' && require.main === module) {
    demonstrateReactHooks().catch(console.error);
} 