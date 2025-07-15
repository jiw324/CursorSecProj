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

interface MemoHook<T> extends Hook {
    value: T;
    deps: DependencyList;
}

interface CallbackHook<T extends Function> extends Hook {
    callback: T;
    deps: DependencyList;
}

interface AsyncHook<T> extends Hook {
    loading: boolean;
    error: Error | null;
    data: T | null;
}

interface DebounceHook<T extends Function> extends Hook {
    callback: T;
    delay: number;
    timeoutId?: NodeJS.Timeout;
}

interface ThrottleHook<T extends Function> extends Hook {
    callback: T;
    limit: number;
    lastRun: number;
}

class HookContext {
    private hooks: Hook[] = [];
    private currentHookIndex = 0;
    private isRendering = false;
    private cleanupQueue: (() => void)[] = [];

    startRender(): void {
        this.currentHookIndex = 0;
        this.isRendering = true;
    }

    endRender(): void {
        this.isRendering = false;
        this.runCleanupQueue();
    }

    getNextHook<T extends Hook>(): T | null {
        if (!this.isRendering) {
            throw new Error('Cannot use hooks outside of render phase');
        }
        return (this.hooks[this.currentHookIndex++] as T) || null;
    }

    addHook<T extends Hook>(hook: T): T {
        if (!this.isRendering) {
            throw new Error('Cannot add hooks outside of render phase');
        }
        this.hooks[this.currentHookIndex++] = hook;
        return hook;
    }

    cleanup(): void {
        this.hooks.forEach(hook => {
            if (hook.cleanup) {
                this.cleanupQueue.push(hook.cleanup);
            }
        });
        this.runCleanupQueue();
        this.hooks = [];
        this.currentHookIndex = 0;
    }

    private runCleanupQueue(): void {
        while (this.cleanupQueue.length > 0) {
            const cleanup = this.cleanupQueue.shift();
            try {
                cleanup?.();
            } catch (error) {
                console.error('Error in cleanup:', error);
            }
        }
    }
}

const globalContext = new HookContext();

function getCurrentContext(): HookContext {
    return globalContext;
}

function useState<T>(initialState: T | (() => T)): [T, Dispatch<T>] {
    const context = getCurrentContext();
    const hook = context.getNextHook<StateHook<T>>() || context.addHook<StateHook<T>>({
        state: initialState instanceof Function ? initialState() : initialState,
        setState: function (value) {
            const newState = value instanceof Function ? value(hook.state) : value;
            if (newState !== hook.state) {
                hook.state = newState;
                triggerUpdate();
            }
        }
    });

    return [hook.state, hook.setState];
}

function useEffect(effect: EffectCallback, deps?: DependencyList): void {
    const context = getCurrentContext();
    const hook = context.getNextHook<EffectHook>() || context.addHook<EffectHook>({
        effect,
        deps
    });

    const hasChangedDeps = !hook.deps || !deps ||
        deps.length !== hook.deps.length ||
        hook.deps.some((dep, i) => !Object.is(dep, deps[i]));

    if (hasChangedDeps) {
        if (hook.cleanup) {
            hook.cleanup();
        }

        hook.deps = deps;
        const cleanup = effect();
        if (cleanup instanceof Function) {
            hook.cleanup = cleanup;
        }
    }
}

function useRef<T>(initialValue: T): { current: T } {
    const context = getCurrentContext();
    const hook = context.getNextHook<RefHook<T>>() || context.addHook<RefHook<T>>({
        current: initialValue
    });

    return { current: hook.current };
}

function useMemo<T>(factory: () => T, deps: DependencyList): T {
    const context = getCurrentContext();
    const hook = context.getNextHook<MemoHook<T>>() || context.addHook<MemoHook<T>>({
        value: factory(),
        deps
    });

    const hasChangedDeps = !hook.deps ||
        deps.length !== hook.deps.length ||
        hook.deps.some((dep, i) => !Object.is(dep, deps[i]));

    if (hasChangedDeps) {
        hook.value = factory();
        hook.deps = deps;
    }

    return hook.value;
}

function useCallback<T extends Function>(callback: T, deps: DependencyList): T {
    return useMemo(() => callback, deps);
}

function useLocalStorage<T>(key: string, initialValue: T): [T, Dispatch<T>] {
    const [storedValue, setStoredValue] = useState<T>(() => {
        try {
            const item = window.localStorage.getItem(key);
            return item ? JSON.parse(item) : initialValue;
        } catch (error) {
            console.error('Error reading from localStorage:', error);
            return initialValue;
        }
    });

    const setValue: Dispatch<T> = (value) => {
        try {
            const newValue = value instanceof Function ? value(storedValue) : value;
            setStoredValue(newValue);
            window.localStorage.setItem(key, JSON.stringify(newValue));
        } catch (error) {
            console.error('Error writing to localStorage:', error);
        }
    };

    return [storedValue, setValue];
}

function useDebounce<T extends Function>(callback: T, delay: number): T {
    const context = getCurrentContext();
    const hook = context.getNextHook<DebounceHook<T>>() || context.addHook<DebounceHook<T>>({
        callback,
        delay,
        cleanup: () => {
            if (hook.timeoutId) {
                clearTimeout(hook.timeoutId);
            }
        }
    });

    return ((...args: any[]) => {
        if (hook.timeoutId) {
            clearTimeout(hook.timeoutId);
        }
        hook.timeoutId = setTimeout(() => {
            hook.callback(...args);
        }, hook.delay);
    }) as unknown as T;
}

function useThrottle<T extends Function>(callback: T, limit: number): T {
    const context = getCurrentContext();
    const hook = context.getNextHook<ThrottleHook<T>>() || context.addHook<ThrottleHook<T>>({
        callback,
        limit,
        lastRun: 0
    });

    return ((...args: any[]) => {
        const now = Date.now();
        if (now - hook.lastRun >= hook.limit) {
            hook.callback(...args);
            hook.lastRun = now;
        }
    }) as unknown as T;
}

function useAsync<T>(asyncFunction: () => Promise<T>, deps: DependencyList = []): AsyncHook<T> {
    const context = getCurrentContext();
    const hook = context.getNextHook<AsyncHook<T>>() || context.addHook<AsyncHook<T>>({
        loading: true,
        error: null,
        data: null
    });

    useEffect(() => {
        hook.loading = true;
        hook.error = null;

        asyncFunction()
            .then(result => {
                hook.data = result;
                hook.loading = false;
            })
            .catch(error => {
                hook.error = error;
                hook.loading = false;
            });
    }, deps);

    return hook;
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

function useInterval(callback: () => void, delay: number | null) {
    const savedCallback = useRef(callback);

    useEffect(() => {
        savedCallback.current = callback;
    }, [callback]);

    useEffect(() => {
        if (delay !== null) {
            const id = setInterval(() => savedCallback.current(), delay);
            return () => clearInterval(id);
        }
    }, [delay]);
}

function usePrevious<T>(value: T): T | undefined {
    const ref = useRef<T>();

    useEffect(() => {
        ref.current = value;
    }, [value]);

    return ref.current;
}

function useEventListener(
    eventName: string,
    handler: (event: Event) => void,
    element: HTMLElement | Window = window
) {
    const savedHandler = useRef(handler);

    useEffect(() => {
        savedHandler.current = handler;
    }, [handler]);

    useEffect(() => {
        const isSupported = element && element.addEventListener;
        if (!isSupported) return;

        const eventListener = (event: Event) => savedHandler.current(event);
        element.addEventListener(eventName, eventListener);

        return () => {
            element.removeEventListener(eventName, eventListener);
        };
    }, [eventName, element]);
}

function useMediaQuery(query: string): boolean {
    const [matches, setMatches] = useState(() =>
        window.matchMedia(query).matches
    );

    useEffect(() => {
        const mediaQuery = window.matchMedia(query);
        const handler = (event: MediaQueryListEvent) => setMatches(event.matches);

        mediaQuery.addListener(handler);
        return () => mediaQuery.removeListener(handler);
    }, [query]);

    return matches;
}

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
        const nextState = reducer(state, action);
        setState(nextState);
    };

    return [state, dispatch];
}

interface StateContextValue<T> {
    state: T;
    dispatch: (action: Action) => void;
}

class StateProvider<T> {
    private subscribers: Array<() => void> = [];
    private state: T;
    private reducer: Reducer<T, Action>;

    constructor(reducer: Reducer<T, Action>, initialState: T) {
        this.state = initialState;
        this.reducer = reducer;
    }

    getState(): T {
        return this.state;
    }

    dispatch(action: Action): void {
        this.state = this.reducer(this.state, action);
        this.subscribers.forEach(callback => callback());
    }

    subscribe(callback: () => void): () => void {
        this.subscribers.push(callback);
        return () => {
            const index = this.subscribers.indexOf(callback);
            if (index !== -1) {
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
        dispatch: (action: Action) => provider.dispatch(action)
    };
}

interface ComponentProps {
    [key: string]: any;
}

type Component<P extends ComponentProps = {}> = (props: P) => void;

function createComponent<P extends ComponentProps>(
    render: (props: P) => void
): Component<P> {
    return function Component(props: P) {
        const context = getCurrentContext();
        context.startRender();

        try {
            render(props);
        } finally {
            context.endRender();
        }
    };
}

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

type AppAction =
    | { type: 'SET_USER'; payload: User }
    | { type: 'SET_LOADING'; payload: boolean }
    | { type: 'SET_ERROR'; payload: string | null }
    | { type: 'ADD_TODO'; payload: Omit<Todo, 'id'> }
    | { type: 'TOGGLE_TODO'; payload: string }
    | { type: 'DELETE_TODO'; payload: string }
    | { type: 'CLEAR_COMPLETED' };

function appReducer(state: AppState, action: AppAction): AppState {
    switch (action.type) {
        case 'SET_USER':
            return { ...state, user: action.payload };
        case 'SET_LOADING':
            return { ...state, loading: action.payload };
        case 'SET_ERROR':
            return { ...state, error: action.payload };
        case 'ADD_TODO':
            return {
                ...state,
                todos: [
                    ...state.todos,
                    {
                        id: Math.random().toString(36).substr(2, 9),
                        ...action.payload
                    }
                ]
            };
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

function triggerUpdate() {
    console.log('State updated, triggering re-render');
}

const initialState: AppState = {
    user: null,
    loading: false,
    error: null,
    todos: []
};

const TodoApp = createComponent<{}>(({ }) => {
    const [state, dispatch] = useReducer(appReducer, initialState);
    const [newTodoText, setNewTodoText] = useState('');
    const inputRef = useRef<HTMLInputElement>(null);
    const { value: showCompleted, toggle: toggleShowCompleted } = useToggle(true);

    const visibleTodos = useMemo(() => {
        return showCompleted
            ? state.todos
            : state.todos.filter(todo => !todo.completed);
    }, [state.todos, showCompleted]);

    const completedCount = useMemo(() => {
        return state.todos.filter(todo => todo.completed).length;
    }, [state.todos]);

    const addTodo = useCallback(() => {
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
            inputRef.current?.focus();
        }
    }, [newTodoText]);

    const simulateLogin = useCallback(async () => {
        dispatch({ type: 'SET_LOADING', payload: true });
        dispatch({ type: 'SET_ERROR', payload: null });

        try {
            await new Promise(resolve => setTimeout(resolve, 1000));

            dispatch({
                type: 'SET_USER',
                payload: {
                    id: '1',
                    name: 'John Doe',
                    email: 'john@example.com',
                    preferences: {
                        theme: 'light',
                        notifications: true
                    }
                }
            });
        } catch (error) {
            dispatch({ type: 'SET_ERROR', payload: error.message });
        } finally {
            dispatch({ type: 'SET_LOADING', payload: false });
        }
    }, []);

    useEffect(() => {
        simulateLogin();
    }, []);

    useEffect(() => {
        const handler = (event: KeyboardEvent) => {
            if (event.key === 'Enter') {
                addTodo();
            }
        };

        window.addEventListener('keypress', handler);
        return () => window.removeEventListener('keypress', handler);
    }, [addTodo]);

    console.log('Rendering TodoApp', { state, visibleTodos, completedCount });
});

class AppProvider {
    private stateProvider: StateProvider<AppState>;
    private todoApp: any;

    constructor() {
        this.stateProvider = new StateProvider(appReducer, initialState);
        this.todoApp = TodoApp;
    }

    render() {
        this.todoApp({});
    }

    getState() {
        return this.stateProvider.getState();
    }

    dispatch(action: AppAction) {
        this.stateProvider.dispatch(action);
    }
}

async function demonstrateReactHooks(): Promise<void> {
    console.log('🎣 React-like Hooks Implementation Demo');
    console.log('=====================================');

    const app = new AppProvider();
    app.render();

    console.log('\n=== React-like Hooks Demo Complete ===');
}

export {
    useState,
    useEffect,
    useRef,
    useMemo,
    useCallback,
    useReducer,
    useLocalStorage,
    useDebounce,
    useThrottle,
    useAsync,
    useCounter,
    useToggle,
    useInterval,
    usePrevious,
    useEventListener,
    useMediaQuery,
    StateProvider,
    createComponent,
    demonstrateReactHooks
};

export type {
    Dispatch,
    EffectCallback,
    DependencyList,
    Hook,
    StateHook,
    EffectHook,
    RefHook,
    MemoHook,
    CallbackHook,
    AsyncHook,
    ComponentProps,
    Component,
    User,
    AppState,
    Todo,
    AppAction
};

if (typeof require !== 'undefined' && require.main === module) {
    demonstrateReactHooks().catch(console.error);
} 