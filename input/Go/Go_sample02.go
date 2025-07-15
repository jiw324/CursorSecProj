package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"runtime"
	"sync"
	"time"
)

type Task struct {
	ID       int           `json:"id"`
	Data     string        `json:"data"`
	Priority int           `json:"priority"`
	Duration time.Duration `json:"duration"`
}

type Result struct {
	TaskID    int           `json:"task_id"`
	Output    string        `json:"output"`
	ProcessedAt time.Time   `json:"processed_at"`
	Duration  time.Duration `json:"duration"`
	WorkerID  int           `json:"worker_id"`
}

type JobStats struct {
	TotalTasks     int           `json:"total_tasks"`
	CompletedTasks int           `json:"completed_tasks"`
	FailedTasks    int           `json:"failed_tasks"`
	TotalDuration  time.Duration `json:"total_duration"`
	AvgDuration    time.Duration `json:"avg_duration"`
}

type WorkerPool struct {
	numWorkers int
	taskQueue  chan Task
	resultQueue chan Result
	wg         sync.WaitGroup
	ctx        context.Context
	cancel     context.CancelFunc
	stats      *JobStats
	mu         sync.Mutex
}

func NewWorkerPool(numWorkers int, queueSize int) *WorkerPool {
	ctx, cancel := context.WithCancel(context.Background())
	return &WorkerPool{
		numWorkers:  numWorkers,
		taskQueue:   make(chan Task, queueSize),
		resultQueue: make(chan Result, queueSize),
		ctx:         ctx,
		cancel:      cancel,
		stats:       &JobStats{},
	}
}

func (wp *WorkerPool) Start() {
	log.Printf("Starting worker pool with %d workers", wp.numWorkers)
	
	for i := 0; i < wp.numWorkers; i++ {
		wp.wg.Add(1)
		go wp.worker(i + 1)
	}
	
	go wp.collectResults()
}

func (wp *WorkerPool) worker(id int) {
	defer wp.wg.Done()
	
	for {
		select {
		case task := <-wp.taskQueue:
			start := time.Now()
			result := wp.processTask(task, id)
			result.Duration = time.Since(start)
			
			select {
			case wp.resultQueue <- result:
			case <-wp.ctx.Done():
				return
			}
			
		case <-wp.ctx.Done():
			log.Printf("Worker %d shutting down", id)
			return
		}
	}
}

func (wp *WorkerPool) processTask(task Task, workerID int) Result {
	time.Sleep(task.Duration)
	
	output := fmt.Sprintf("Processed task %d: %s (Worker %d)", task.ID, task.Data, workerID)
	
	return Result{
		TaskID:      task.ID,
		Output:      output,
		ProcessedAt: time.Now(),
		WorkerID:    workerID,
	}
}

func (wp *WorkerPool) collectResults() {
	for {
		select {
		case result := <-wp.resultQueue:
			wp.mu.Lock()
			wp.stats.CompletedTasks++
			wp.stats.TotalDuration += result.Duration
			if wp.stats.CompletedTasks > 0 {
				wp.stats.AvgDuration = wp.stats.TotalDuration / time.Duration(wp.stats.CompletedTasks)
			}
			wp.mu.Unlock()
			
			log.Printf("Task %d completed by worker %d in %v", 
				result.TaskID, result.WorkerID, result.Duration)
			
		case <-wp.ctx.Done():
			return
		}
	}
}

func (wp *WorkerPool) SubmitTask(task Task) {
	wp.mu.Lock()
	wp.stats.TotalTasks++
	wp.mu.Unlock()
	
	select {
	case wp.taskQueue <- task:
	case <-wp.ctx.Done():
	}
}

func (wp *WorkerPool) Stop() {
	log.Println("Stopping worker pool...")
	close(wp.taskQueue)
	wp.wg.Wait()
	wp.cancel()
	close(wp.resultQueue)
}

func (wp *WorkerPool) GetStats() JobStats {
	wp.mu.Lock()
	defer wp.mu.Unlock()
	return *wp.stats
}

type Pipeline struct {
	stages []PipelineStage
	input  chan interface{}
	output chan interface{}
	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

type PipelineStage func(interface{}) interface{}

func NewPipeline(stages ...PipelineStage) *Pipeline {
	ctx, cancel := context.WithCancel(context.Background())
	return &Pipeline{
		stages: stages,
		input:  make(chan interface{}, 100),
		output: make(chan interface{}, 100),
		ctx:    ctx,
		cancel: cancel,
	}
}

func (p *Pipeline) Start() {
	channels := make([]chan interface{}, len(p.stages)+1)
	channels[0] = p.input
	channels[len(p.stages)] = p.output
	
	for i := 1; i < len(p.stages); i++ {
		channels[i] = make(chan interface{}, 100)
	}
	
	for i, stage := range p.stages {
		p.wg.Add(1)
		go p.runStage(stage, channels[i], channels[i+1])
	}
}

func (p *Pipeline) runStage(stage PipelineStage, input, output chan interface{}) {
	defer p.wg.Done()
	defer close(output)
	
	for {
		select {
		case data, ok := <-input:
			if !ok {
				return
			}
			result := stage(data)
			select {
			case output <- result:
			case <-p.ctx.Done():
				return
			}
		case <-p.ctx.Done():
			return
		}
	}
}

func (p *Pipeline) Process(data interface{}) {
	select {
	case p.input <- data:
	case <-p.ctx.Done():
	}
}

func (p *Pipeline) Results() <-chan interface{} {
	return p.output
}

func (p *Pipeline) Stop() {
	close(p.input)
	p.wg.Wait()
	p.cancel()
}

type RateLimiter struct {
	rate     time.Duration
	tokens   chan struct{}
	ticker   *time.Ticker
	ctx      context.Context
	cancel   context.CancelFunc
}

func NewRateLimiter(rate time.Duration, burst int) *RateLimiter {
	ctx, cancel := context.WithCancel(context.Background())
	rl := &RateLimiter{
		rate:   rate,
		tokens: make(chan struct{}, burst),
		ticker: time.NewTicker(rate),
		ctx:    ctx,
		cancel: cancel,
	}
	
	for i := 0; i < burst; i++ {
		rl.tokens <- struct{}{}
	}
	
	go rl.refillTokens()
	return rl
}

func (rl *RateLimiter) refillTokens() {
	for {
		select {
		case <-rl.ticker.C:
			select {
			case rl.tokens <- struct{}{}:
			default:
			}
		case <-rl.ctx.Done():
			rl.ticker.Stop()
			return
		}
	}
}

func (rl *RateLimiter) Wait() {
	select {
	case <-rl.tokens:
	case <-rl.ctx.Done():
	}
}

func (rl *RateLimiter) Stop() {
	rl.cancel()
}

func FanOut(input <-chan Task, numWorkers int) []<-chan Task {
	outputs := make([]<-chan Task, numWorkers)
	
	for i := 0; i < numWorkers; i++ {
		output := make(chan Task)
		outputs[i] = output
		
		go func(out chan<- Task) {
			defer close(out)
			for task := range input {
				out <- task
			}
		}(output)
	}
	
	return outputs
}

func FanIn(inputs ...<-chan Result) <-chan Result {
	output := make(chan Result)
	var wg sync.WaitGroup
	
	wg.Add(len(inputs))
	for _, input := range inputs {
		go func(ch <-chan Result) {
			defer wg.Done()
			for result := range ch {
				output <- result
			}
		}(input)
	}
	
	go func() {
		wg.Wait()
		close(output)
	}()
	
	return output
}

type ConcurrentMap struct {
	data map[string]interface{}
	mu   sync.RWMutex
}

func NewConcurrentMap() *ConcurrentMap {
	return &ConcurrentMap{
		data: make(map[string]interface{}),
	}
}

func (cm *ConcurrentMap) Set(key string, value interface{}) {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	cm.data[key] = value
}

func (cm *ConcurrentMap) Get(key string) (interface{}, bool) {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	value, exists := cm.data[key]
	return value, exists
}

func (cm *ConcurrentMap) Delete(key string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	delete(cm.data, key)
}

func (cm *ConcurrentMap) Keys() []string {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	
	keys := make([]string, 0, len(cm.data))
	for key := range cm.data {
		keys = append(keys, key)
	}
	return keys
}

func (cm *ConcurrentMap) Size() int {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	return len(cm.data)
}

func main() {
	fmt.Println("Go Concurrent Processing Demo")
	fmt.Println("=============================")
	
	log.Println("\n--- Worker Pool Demo ---")
	demoWorkerPool()
	
	log.Println("\n--- Pipeline Demo ---")
	demoPipeline()
	
	log.Println("\n--- Rate Limiter Demo ---")
	demoRateLimiter()
	
	log.Println("\n--- Concurrent Map Demo ---")
	demoConcurrentMap()
	
	log.Println("\n=== Concurrent Processing Demo Complete ===")
}

func demoWorkerPool() {
	pool := NewWorkerPool(runtime.NumCPU(), 100)
	pool.Start()
	
	for i := 1; i <= 20; i++ {
		task := Task{
			ID:       i,
			Data:     fmt.Sprintf("Task-%d", i),
			Priority: rand.Intn(5) + 1,
			Duration: time.Duration(rand.Intn(500)+100) * time.Millisecond,
		}
		pool.SubmitTask(task)
	}
	
	time.Sleep(3 * time.Second)
	
	stats := pool.GetStats()
	log.Printf("Worker Pool Stats: %+v", stats)
	
	pool.Stop()
}

func demoPipeline() {
	stage1 := func(data interface{}) interface{} {
		s := data.(string)
		return fmt.Sprintf("Stage1[%s]", s)
	}
	
	stage2 := func(data interface{}) interface{} {
		s := data.(string)
		return fmt.Sprintf("Stage2[%s]", s)
	}
	
	stage3 := func(data interface{}) interface{} {
		s := data.(string)
		return fmt.Sprintf("Stage3[%s]", s)
	}
	
	pipeline := NewPipeline(stage1, stage2, stage3)
	pipeline.Start()
	
	go func() {
		for i := 1; i <= 10; i++ {
			pipeline.Process(fmt.Sprintf("Data-%d", i))
		}
		pipeline.Stop()
	}()
	
	for result := range pipeline.Results() {
		log.Printf("Pipeline result: %s", result)
	}
}

func demoRateLimiter() {
	limiter := NewRateLimiter(100*time.Millisecond, 5)
	defer limiter.Stop()
	
	start := time.Now()
	for i := 1; i <= 10; i++ {
		limiter.Wait()
		log.Printf("Rate limited operation %d at %v", i, time.Since(start))
	}
}

func demoConcurrentMap() {
	cm := NewConcurrentMap()
	var wg sync.WaitGroup
	
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			cm.Set(fmt.Sprintf("key-%d", id), fmt.Sprintf("value-%d", id))
		}(i)
	}
	
	wg.Wait()
	
	log.Printf("Concurrent map size: %d", cm.Size())
	log.Printf("Keys: %v", cm.Keys())
	
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			if value, exists := cm.Get(fmt.Sprintf("key-%d", id)); exists {
				log.Printf("Found: %s = %s", fmt.Sprintf("key-%d", id), value)
			}
		}(i)
	}
	
	wg.Wait()
} 