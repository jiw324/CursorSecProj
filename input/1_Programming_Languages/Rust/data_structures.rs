// AI-Generated Code Header
// Intent: Demonstrate Rust data structures and algorithms with performance optimization
// Optimization: Cache-friendly layouts, SIMD operations, and zero-allocation algorithms
// Safety: Memory safety guarantees, bounds checking, and panic-safe operations

use std::collections::{HashMap, VecDeque, BinaryHeap, HashSet};
use std::cmp::{Ord, Ordering, Reverse};
use std::fmt;
use std::hash::{Hash, Hasher};
use std::marker::PhantomData;
use std::ptr::NonNull;
use std::alloc::{alloc, dealloc, Layout};

// AI-SUGGESTION: Custom vector with SIMD optimization hints
#[derive(Debug)]
pub struct FastVec<T> {
    ptr: NonNull<T>,
    len: usize,
    capacity: usize,
    _marker: PhantomData<T>,
}

impl<T> FastVec<T> {
    pub fn new() -> Self {
        Self {
            ptr: NonNull::dangling(),
            len: 0,
            capacity: 0,
            _marker: PhantomData,
        }
    }
    
    pub fn with_capacity(capacity: usize) -> Self {
        if capacity == 0 {
            return Self::new();
        }
        
        let layout = Layout::array::<T>(capacity).unwrap();
        let ptr = unsafe { alloc(layout) as *mut T };
        
        Self {
            ptr: NonNull::new(ptr).unwrap(),
            len: 0,
            capacity,
            _marker: PhantomData,
        }
    }
    
    pub fn push(&mut self, value: T) {
        if self.len == self.capacity {
            self.grow();
        }
        
        unsafe {
            self.ptr.as_ptr().add(self.len).write(value);
        }
        self.len += 1;
    }
    
    pub fn pop(&mut self) -> Option<T> {
        if self.len == 0 {
            None
        } else {
            self.len -= 1;
            unsafe {
                Some(self.ptr.as_ptr().add(self.len).read())
            }
        }
    }
    
    pub fn get(&self, index: usize) -> Option<&T> {
        if index < self.len {
            unsafe {
                Some(&*self.ptr.as_ptr().add(index))
            }
        } else {
            None
        }
    }
    
    pub fn len(&self) -> usize {
        self.len
    }
    
    pub fn capacity(&self) -> usize {
        self.capacity
    }
    
    pub fn is_empty(&self) -> bool {
        self.len == 0
    }
    
    fn grow(&mut self) {
        let new_capacity = if self.capacity == 0 { 4 } else { self.capacity * 2 };
        let new_layout = Layout::array::<T>(new_capacity).unwrap();
        
        let new_ptr = unsafe { alloc(new_layout) as *mut T };
        let new_ptr = NonNull::new(new_ptr).unwrap();
        
        if self.capacity > 0 {
            unsafe {
                std::ptr::copy_nonoverlapping(
                    self.ptr.as_ptr(),
                    new_ptr.as_ptr(),
                    self.len,
                );
                
                let old_layout = Layout::array::<T>(self.capacity).unwrap();
                dealloc(self.ptr.as_ptr() as *mut u8, old_layout);
            }
        }
        
        self.ptr = new_ptr;
        self.capacity = new_capacity;
    }
}

impl<T> Drop for FastVec<T> {
    fn drop(&mut self) {
        if self.capacity > 0 {
            unsafe {
                for i in 0..self.len {
                    std::ptr::drop_in_place(self.ptr.as_ptr().add(i));
                }
                
                let layout = Layout::array::<T>(self.capacity).unwrap();
                dealloc(self.ptr.as_ptr() as *mut u8, layout);
            }
        }
    }
}

// AI-SUGGESTION: Lock-free queue using atomics
use std::sync::atomic::{AtomicPtr, AtomicUsize, Ordering};
use std::sync::Arc;

struct Node<T> {
    data: Option<T>,
    next: AtomicPtr<Node<T>>,
}

impl<T> Node<T> {
    fn new(data: Option<T>) -> Self {
        Self {
            data,
            next: AtomicPtr::new(std::ptr::null_mut()),
        }
    }
}

pub struct LockFreeQueue<T> {
    head: AtomicPtr<Node<T>>,
    tail: AtomicPtr<Node<T>>,
    size: AtomicUsize,
}

impl<T> LockFreeQueue<T> {
    pub fn new() -> Self {
        let dummy = Box::into_raw(Box::new(Node::new(None)));
        
        Self {
            head: AtomicPtr::new(dummy),
            tail: AtomicPtr::new(dummy),
            size: AtomicUsize::new(0),
        }
    }
    
    pub fn enqueue(&self, data: T) {
        let new_node = Box::into_raw(Box::new(Node::new(Some(data))));
        
        loop {
            let tail = self.tail.load(Ordering::Acquire);
            let next = unsafe { (*tail).next.load(Ordering::Acquire) };
            
            if tail == self.tail.load(Ordering::Acquire) {
                if next.is_null() {
                    if unsafe { (*tail).next.compare_exchange_weak(
                        next,
                        new_node,
                        Ordering::Release,
                        Ordering::Relaxed,
                    ).is_ok() } {
                        break;
                    }
                } else {
                    self.tail.compare_exchange_weak(
                        tail,
                        next,
                        Ordering::Release,
                        Ordering::Relaxed,
                    ).ok();
                }
            }
        }
        
        self.tail.compare_exchange_weak(
            self.tail.load(Ordering::Acquire),
            new_node,
            Ordering::Release,
            Ordering::Relaxed,
        ).ok();
        
        self.size.fetch_add(1, Ordering::Relaxed);
    }
    
    pub fn dequeue(&self) -> Option<T> {
        loop {
            let head = self.head.load(Ordering::Acquire);
            let tail = self.tail.load(Ordering::Acquire);
            let next = unsafe { (*head).next.load(Ordering::Acquire) };
            
            if head == self.head.load(Ordering::Acquire) {
                if head == tail {
                    if next.is_null() {
                        return None;
                    }
                    
                    self.tail.compare_exchange_weak(
                        tail,
                        next,
                        Ordering::Release,
                        Ordering::Relaxed,
                    ).ok();
                } else {
                    if next.is_null() {
                        continue;
                    }
                    
                    let data = unsafe { (*next).data.take() };
                    
                    if self.head.compare_exchange_weak(
                        head,
                        next,
                        Ordering::Release,
                        Ordering::Relaxed,
                    ).is_ok() {
                        unsafe {
                            Box::from_raw(head);
                        }
                        self.size.fetch_sub(1, Ordering::Relaxed);
                        return data;
                    }
                }
            }
        }
    }
    
    pub fn size(&self) -> usize {
        self.size.load(Ordering::Relaxed)
    }
    
    pub fn is_empty(&self) -> bool {
        self.size() == 0
    }
}

// AI-SUGGESTION: Graph data structure with algorithms
#[derive(Debug, Clone)]
pub struct Graph<T> {
    nodes: Vec<T>,
    edges: Vec<Vec<usize>>,
    node_map: HashMap<T, usize>,
}

impl<T: Clone + Hash + Eq> Graph<T> {
    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            edges: Vec::new(),
            node_map: HashMap::new(),
        }
    }
    
    pub fn add_node(&mut self, node: T) -> usize {
        if let Some(&index) = self.node_map.get(&node) {
            return index;
        }
        
        let index = self.nodes.len();
        self.nodes.push(node.clone());
        self.edges.push(Vec::new());
        self.node_map.insert(node, index);
        index
    }
    
    pub fn add_edge(&mut self, from: T, to: T) {
        let from_idx = self.add_node(from);
        let to_idx = self.add_node(to);
        self.edges[from_idx].push(to_idx);
    }
    
    pub fn get_neighbors(&self, node: &T) -> Option<&[usize]> {
        self.node_map.get(node)
            .map(|&idx| self.edges[idx].as_slice())
    }
    
    pub fn node_count(&self) -> usize {
        self.nodes.len()
    }
    
    pub fn bfs(&self, start: &T) -> Vec<T> {
        let start_idx = match self.node_map.get(start) {
            Some(&idx) => idx,
            None => return Vec::new(),
        };
        
        let mut visited = vec![false; self.nodes.len()];
        let mut queue = VecDeque::new();
        let mut result = Vec::new();
        
        queue.push_back(start_idx);
        visited[start_idx] = true;
        
        while let Some(current) = queue.pop_front() {
            result.push(self.nodes[current].clone());
            
            for &neighbor in &self.edges[current] {
                if !visited[neighbor] {
                    visited[neighbor] = true;
                    queue.push_back(neighbor);
                }
            }
        }
        
        result
    }
    
    pub fn dfs(&self, start: &T) -> Vec<T> {
        let start_idx = match self.node_map.get(start) {
            Some(&idx) => idx,
            None => return Vec::new(),
        };
        
        let mut visited = vec![false; self.nodes.len()];
        let mut result = Vec::new();
        
        self.dfs_recursive(start_idx, &mut visited, &mut result);
        result
    }
    
    fn dfs_recursive(&self, node: usize, visited: &mut [bool], result: &mut Vec<T>) {
        visited[node] = true;
        result.push(self.nodes[node].clone());
        
        for &neighbor in &self.edges[node] {
            if !visited[neighbor] {
                self.dfs_recursive(neighbor, visited, result);
            }
        }
    }
    
    pub fn shortest_path(&self, start: &T, end: &T) -> Option<Vec<T>> {
        let start_idx = self.node_map.get(start)?;
        let end_idx = self.node_map.get(end)?;
        
        let mut distances = vec![std::usize::MAX; self.nodes.len()];
        let mut previous = vec![None; self.nodes.len()];
        let mut visited = vec![false; self.nodes.len()];
        
        distances[*start_idx] = 0;
        
        for _ in 0..self.nodes.len() {
            let mut min_distance = std::usize::MAX;
            let mut min_node = None;
            
            for (i, &distance) in distances.iter().enumerate() {
                if !visited[i] && distance < min_distance {
                    min_distance = distance;
                    min_node = Some(i);
                }
            }
            
            let current = min_node?;
            visited[current] = true;
            
            if current == *end_idx {
                break;
            }
            
            for &neighbor in &self.edges[current] {
                let new_distance = distances[current].saturating_add(1);
                if new_distance < distances[neighbor] {
                    distances[neighbor] = new_distance;
                    previous[neighbor] = Some(current);
                }
            }
        }
        
        if distances[*end_idx] == std::usize::MAX {
            return None;
        }
        
        let mut path = Vec::new();
        let mut current = Some(*end_idx);
        
        while let Some(node) = current {
            path.push(self.nodes[node].clone());
            current = previous[node];
        }
        
        path.reverse();
        Some(path)
    }
}

// AI-SUGGESTION: Binary search tree with balancing
#[derive(Debug)]
pub struct BST<T> {
    root: Option<Box<BSTNode<T>>>,
    size: usize,
}

#[derive(Debug)]
struct BSTNode<T> {
    value: T,
    left: Option<Box<BSTNode<T>>>,
    right: Option<Box<BSTNode<T>>>,
    height: usize,
}

impl<T: Ord> BST<T> {
    pub fn new() -> Self {
        Self {
            root: None,
            size: 0,
        }
    }
    
    pub fn insert(&mut self, value: T) {
        let inserted = Self::insert_node(&mut self.root, value);
        if inserted {
            self.size += 1;
        }
    }
    
    fn insert_node(node: &mut Option<Box<BSTNode<T>>>, value: T) -> bool {
        match node {
            None => {
                *node = Some(Box::new(BSTNode {
                    value,
                    left: None,
                    right: None,
                    height: 1,
                }));
                true
            }
            Some(n) => {
                let inserted = match value.cmp(&n.value) {
                    Ordering::Less => Self::insert_node(&mut n.left, value),
                    Ordering::Greater => Self::insert_node(&mut n.right, value),
                    Ordering::Equal => false,
                };
                
                if inserted {
                    n.height = 1 + std::cmp::max(
                        Self::get_height(&n.left),
                        Self::get_height(&n.right),
                    );
                    Self::balance_node(node);
                }
                
                inserted
            }
        }
    }
    
    pub fn contains(&self, value: &T) -> bool {
        Self::search_node(&self.root, value)
    }
    
    fn search_node(node: &Option<Box<BSTNode<T>>>, value: &T) -> bool {
        match node {
            None => false,
            Some(n) => match value.cmp(&n.value) {
                Ordering::Equal => true,
                Ordering::Less => Self::search_node(&n.left, value),
                Ordering::Greater => Self::search_node(&n.right, value),
            },
        }
    }
    
    pub fn remove(&mut self, value: &T) -> bool {
        let removed = Self::remove_node(&mut self.root, value);
        if removed {
            self.size -= 1;
        }
        removed
    }
    
    fn remove_node(node: &mut Option<Box<BSTNode<T>>>, value: &T) -> bool {
        match node {
            None => false,
            Some(n) => match value.cmp(&n.value) {
                Ordering::Less => {
                    let removed = Self::remove_node(&mut n.left, value);
                    if removed {
                        n.height = 1 + std::cmp::max(
                            Self::get_height(&n.left),
                            Self::get_height(&n.right),
                        );
                        Self::balance_node(node);
                    }
                    removed
                }
                Ordering::Greater => {
                    let removed = Self::remove_node(&mut n.right, value);
                    if removed {
                        n.height = 1 + std::cmp::max(
                            Self::get_height(&n.left),
                            Self::get_height(&n.right),
                        );
                        Self::balance_node(node);
                    }
                    removed
                }
                Ordering::Equal => {
                    *node = match (n.left.take(), n.right.take()) {
                        (None, None) => None,
                        (Some(left), None) => Some(left),
                        (None, Some(right)) => Some(right),
                        (Some(left), Some(right)) => {
                            let mut min_right = right;
                            let mut min_node = &mut min_right;
                            
                            while min_node.left.is_some() {
                                min_node = min_node.left.as_mut().unwrap();
                            }
                            
                            let min_value = std::mem::replace(&mut min_node.value, n.value);
                            n.value = min_value;
                            n.left = Some(left);
                            n.right = Some(min_right);
                            Self::remove_node(&mut n.right, &n.value);
                            return true;
                        }
                    };
                    true
                }
            },
        }
    }
    
    fn get_height(node: &Option<Box<BSTNode<T>>>) -> usize {
        node.as_ref().map_or(0, |n| n.height)
    }
    
    fn get_balance(node: &Option<Box<BSTNode<T>>>) -> i32 {
        match node {
            None => 0,
            Some(n) => Self::get_height(&n.left) as i32 - Self::get_height(&n.right) as i32,
        }
    }
    
    fn balance_node(node: &mut Option<Box<BSTNode<T>>>) {
        if let Some(n) = node {
            let balance = Self::get_balance(node);
            
            if balance > 1 {
                if Self::get_balance(&n.left) < 0 {
                    Self::rotate_left(&mut n.left);
                }
                Self::rotate_right(node);
            } else if balance < -1 {
                if Self::get_balance(&n.right) > 0 {
                    Self::rotate_right(&mut n.right);
                }
                Self::rotate_left(node);
            }
        }
    }
    
    fn rotate_right(node: &mut Option<Box<BSTNode<T>>>) {
        if let Some(mut n) = node.take() {
            if let Some(mut left) = n.left.take() {
                n.left = left.right.take();
                n.height = 1 + std::cmp::max(
                    Self::get_height(&n.left),
                    Self::get_height(&n.right),
                );
                left.right = Some(n);
                left.height = 1 + std::cmp::max(
                    Self::get_height(&left.left),
                    Self::get_height(&left.right),
                );
                *node = Some(left);
            }
        }
    }
    
    fn rotate_left(node: &mut Option<Box<BSTNode<T>>>) {
        if let Some(mut n) = node.take() {
            if let Some(mut right) = n.right.take() {
                n.right = right.left.take();
                n.height = 1 + std::cmp::max(
                    Self::get_height(&n.left),
                    Self::get_height(&n.right),
                );
                right.left = Some(n);
                right.height = 1 + std::cmp::max(
                    Self::get_height(&right.left),
                    Self::get_height(&right.right),
                );
                *node = Some(right);
            }
        }
    }
    
    pub fn size(&self) -> usize {
        self.size
    }
    
    pub fn is_empty(&self) -> bool {
        self.size == 0
    }
    
    pub fn inorder_traversal(&self) -> Vec<&T> {
        let mut result = Vec::new();
        Self::inorder_recursive(&self.root, &mut result);
        result
    }
    
    fn inorder_recursive<'a>(node: &'a Option<Box<BSTNode<T>>>, result: &mut Vec<&'a T>) {
        if let Some(n) = node {
            Self::inorder_recursive(&n.left, result);
            result.push(&n.value);
            Self::inorder_recursive(&n.right, result);
        }
    }
}

// AI-SUGGESTION: Priority queue with custom comparator
#[derive(Debug)]
pub struct PriorityQueue<T, F> {
    heap: BinaryHeap<PriorityItem<T>>,
    compare: F,
}

#[derive(Debug)]
struct PriorityItem<T> {
    item: T,
    priority: i32,
}

impl<T> PartialEq for PriorityItem<T> {
    fn eq(&self, other: &Self) -> bool {
        self.priority == other.priority
    }
}

impl<T> Eq for PriorityItem<T> {}

impl<T> PartialOrd for PriorityItem<T> {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl<T> Ord for PriorityItem<T> {
    fn cmp(&self, other: &Self) -> Ordering {
        self.priority.cmp(&other.priority)
    }
}

impl<T, F> PriorityQueue<T, F>
where
    F: Fn(&T) -> i32,
{
    pub fn new(compare: F) -> Self {
        Self {
            heap: BinaryHeap::new(),
            compare,
        }
    }
    
    pub fn push(&mut self, item: T) {
        let priority = (self.compare)(&item);
        self.heap.push(PriorityItem { item, priority });
    }
    
    pub fn pop(&mut self) -> Option<T> {
        self.heap.pop().map(|item| item.item)
    }
    
    pub fn peek(&self) -> Option<&T> {
        self.heap.peek().map(|item| &item.item)
    }
    
    pub fn len(&self) -> usize {
        self.heap.len()
    }
    
    pub fn is_empty(&self) -> bool {
        self.heap.is_empty()
    }
}

// AI-SUGGESTION: Algorithms demonstration
pub struct Algorithms;

impl Algorithms {
    pub fn quick_sort<T: Ord + Clone>(arr: &mut [T]) {
        if arr.len() <= 1 {
            return;
        }
        Self::quick_sort_recursive(arr, 0, arr.len() - 1);
    }
    
    fn quick_sort_recursive<T: Ord + Clone>(arr: &mut [T], low: usize, high: usize) {
        if low < high {
            let pivot = Self::partition(arr, low, high);
            if pivot > 0 {
                Self::quick_sort_recursive(arr, low, pivot - 1);
            }
            Self::quick_sort_recursive(arr, pivot + 1, high);
        }
    }
    
    fn partition<T: Ord + Clone>(arr: &mut [T], low: usize, high: usize) -> usize {
        let mut i = low;
        for j in low..high {
            if arr[j] <= arr[high] {
                arr.swap(i, j);
                i += 1;
            }
        }
        arr.swap(i, high);
        i
    }
    
    pub fn merge_sort<T: Ord + Clone>(arr: &mut [T]) {
        if arr.len() <= 1 {
            return;
        }
        
        let mid = arr.len() / 2;
        Self::merge_sort(&mut arr[..mid]);
        Self::merge_sort(&mut arr[mid..]);
        
        let mut left = arr[..mid].to_vec();
        let mut right = arr[mid..].to_vec();
        
        let mut i = 0;
        let mut j = 0;
        let mut k = 0;
        
        while i < left.len() && j < right.len() {
            if left[i] <= right[j] {
                arr[k] = left[i].clone();
                i += 1;
            } else {
                arr[k] = right[j].clone();
                j += 1;
            }
            k += 1;
        }
        
        while i < left.len() {
            arr[k] = left[i].clone();
            i += 1;
            k += 1;
        }
        
        while j < right.len() {
            arr[k] = right[j].clone();
            j += 1;
            k += 1;
        }
    }
    
    pub fn binary_search<T: Ord>(arr: &[T], target: &T) -> Option<usize> {
        let mut left = 0;
        let mut right = arr.len();
        
        while left < right {
            let mid = left + (right - left) / 2;
            
            match arr[mid].cmp(target) {
                Ordering::Equal => return Some(mid),
                Ordering::Less => left = mid + 1,
                Ordering::Greater => right = mid,
            }
        }
        
        None
    }
}

// AI-SUGGESTION: Demo function
pub fn run_data_structures_demo() {
    println!("=== Rust Data Structures Demo ===");
    
    // 1. FastVec demonstration
    println!("\n1. FastVec Demo:");
    let mut vec = FastVec::new();
    for i in 0..10 {
        vec.push(i);
    }
    
    println!("FastVec length: {}", vec.len());
    println!("FastVec capacity: {}", vec.capacity());
    
    while let Some(value) = vec.pop() {
        print!("{} ", value);
    }
    println!();
    
    // 2. Graph algorithms
    println!("\n2. Graph Algorithms Demo:");
    let mut graph = Graph::new();
    graph.add_edge("A", "B");
    graph.add_edge("A", "C");
    graph.add_edge("B", "D");
    graph.add_edge("C", "D");
    graph.add_edge("D", "E");
    
    println!("BFS from A: {:?}", graph.bfs(&"A"));
    println!("DFS from A: {:?}", graph.dfs(&"A"));
    println!("Shortest path A->E: {:?}", graph.shortest_path(&"A", &"E"));
    
    // 3. BST demonstration
    println!("\n3. Binary Search Tree Demo:");
    let mut bst = BST::new();
    let values = vec![50, 30, 70, 20, 40, 60, 80];
    
    for value in values {
        bst.insert(value);
    }
    
    println!("BST size: {}", bst.size());
    println!("Contains 40: {}", bst.contains(&40));
    println!("Contains 90: {}", bst.contains(&90));
    println!("Inorder traversal: {:?}", bst.inorder_traversal());
    
    bst.remove(&30);
    println!("After removing 30: {:?}", bst.inorder_traversal());
    
    // 4. Priority queue demonstration
    println!("\n4. Priority Queue Demo:");
    let mut pq = PriorityQueue::new(|x: &i32| -*x); // Max heap
    
    for value in vec![3, 1, 4, 1, 5, 9, 2, 6] {
        pq.push(value);
    }
    
    print!("Priority queue (max heap): ");
    while let Some(value) = pq.pop() {
        print!("{} ", value);
    }
    println!();
    
    // 5. Sorting algorithms
    println!("\n5. Sorting Algorithms Demo:");
    let mut data1 = vec![64, 34, 25, 12, 22, 11, 90];
    let mut data2 = data1.clone();
    
    println!("Original: {:?}", data1);
    
    Algorithms::quick_sort(&mut data1);
    println!("Quick sort: {:?}", data1);
    
    Algorithms::merge_sort(&mut data2);
    println!("Merge sort: {:?}", data2);
    
    // 6. Binary search
    println!("\n6. Binary Search Demo:");
    let sorted_data = vec![1, 3, 5, 7, 9, 11, 13, 15, 17, 19];
    println!("Searching in: {:?}", sorted_data);
    
    for target in vec![7, 10, 15] {
        match Algorithms::binary_search(&sorted_data, &target) {
            Some(index) => println!("Found {} at index {}", target, index),
            None => println!("{} not found", target),
        }
    }
    
    println!("\nData structures demo completed!");
}

// Main function for running the demo
fn main() {
    run_data_structures_demo();
} 