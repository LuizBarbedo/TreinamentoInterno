import { useEffect, useState, useRef } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'
import { computeDisciplineBadges } from '../lib/badges'
import { BadgeGrid, InlineBadges, BadgeUnlocked } from '../components/Badges'
import { FiPlay, FiFileText, FiCheckCircle, FiLock, FiCheck, FiX, FiDownload, FiClipboard, FiUpload, FiFile, FiEdit3, FiSend, FiExternalLink, FiTrash2 } from 'react-icons/fi'
import './DisciplineDetail.css'

// Normaliza os arquivos de apoio da atividade (formato novo `files` ou legado file_url)
function getActivityFiles(act) {
  if (!act) return []
  if (Array.isArray(act.files) && act.files.length > 0) return act.files
  if (act.file_url) {
    return [{
      url: act.file_url,
      name: (act.file_path && act.file_path.split('/').pop()) || 'atividade.pdf'
    }]
  }
  return []
}

function getEmbedUrl(url) {
  if (!url) return null
  let match = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]+)/)
  if (match) return `https://www.youtube.com/embed/${match[1]}?rel=0`
  if (url.includes('youtube.com/embed/')) return url
  match = url.match(/vimeo\.com\/(\d+)/)
  if (match) return `https://player.vimeo.com/video/${match[1]}`
  match = url.match(/drive\.google\.com\/file\/d\/([\w-]+)/)
  if (match) return `https://drive.google.com/file/d/${match[1]}/preview`
  return url
}

export default function DisciplineDetail() {
  const { id } = useParams()
  const { user, fullAccess } = useAuth()
  const [discipline, setDiscipline] = useState(null)
  const [lessons, setLessons] = useState([])
  const [materials, setMaterials] = useState([])
  const [completedLessons, setCompletedLessons] = useState(new Set())
  const [activeTab, setActiveTab] = useState('aulas')

  // Atividade Prática state
  const [practicalActivity, setPracticalActivity] = useState(null)
  const [practicalSubmission, setPracticalSubmission] = useState(null)
  const [submissionMode, setSubmissionMode] = useState('text') // 'text' | 'file'
  const [submissionText, setSubmissionText] = useState('')
  const [submissionFile, setSubmissionFile] = useState(null)
  const [submittingActivity, setSubmittingActivity] = useState(false)
  const submissionFileRef = useRef(null)
  const [activeLesson, setActiveLesson] = useState(null)
  const [loading, setLoading] = useState(true)

  // Lesson quiz state
  const [lessonQuizQuestions, setLessonQuizQuestions] = useState({})
  const [activeLessonQuiz, setActiveLessonQuiz] = useState(null)
  const [lessonQuizAnswers, setLessonQuizAnswers] = useState({})
  const [lessonQuizSubmitted, setLessonQuizSubmitted] = useState(false)
  const [lessonQuizScore, setLessonQuizScore] = useState(null)
  const [loadingQuiz, setLoadingQuiz] = useState(false)

  // Video watched state
  const [watchedLessons, setWatchedLessons] = useState(new Set())
  const [watchTimers, setWatchTimers] = useState({})
  const [watchReady, setWatchReady] = useState(new Set())

  // Badge state
  const [disciplineBadges, setDisciplineBadges] = useState([])
  const [perfectLessonIds, setPerfectLessonIds] = useState(new Set())
  const [lessonBadges, setLessonBadges] = useState(new Map())
  const [newBadge, setNewBadge] = useState(null)
  const [lessonQuizResultsData, setLessonQuizResultsData] = useState([])
  const [finalQuizResultData, setFinalQuizResultData] = useState(null)

  // Ranking state
  const [ranking, setRanking] = useState([])
  const [loadingRanking, setLoadingRanking] = useState(true)

  // Track whether the discipline has a final quiz
  const [hasFinalQuiz, setHasFinalQuiz] = useState(null)

  // Lessons that have a lesson quiz cadastrado
  const [lessonsWithQuiz, setLessonsWithQuiz] = useState(new Set())

  const completedCount = completedLessons.size
  const allLessonsCompleted = lessons.length > 0 && completedLessons.size >= lessons.length
  const progressPercent = lessons.length > 0 ? Math.round((completedCount / lessons.length) * 100) : 0

  const completedLessonQuizIds = new Set(lessonQuizResultsData.map(r => r.lesson_id))
  const pendingLessonQuizCount = [...lessonsWithQuiz].filter(lid => !completedLessonQuizIds.has(lid)).length
  const allLessonQuizzesDone = pendingLessonQuizCount === 0
  const canAccessFinalQuiz = fullAccess || (allLessonsCompleted && allLessonQuizzesDone)

  useEffect(() => {
    fetchData()
    fetchRanking()
  }, [id])

  // When all lessons are completed and discipline has no final quiz, auto-complete discipline
  useEffect(() => {
    if (allLessonsCompleted && hasFinalQuiz === false) {
      const autoCompleteDiscipline = async () => {
        await supabase.from('user_progress').upsert({
          user_id: user.id,
          discipline_id: id,
          completed: true,
          completed_at: new Date().toISOString()
        }, { onConflict: 'user_id,discipline_id' })
      }
      autoCompleteDiscipline()
    }
  }, [allLessonsCompleted, hasFinalQuiz])

  const fetchData = async () => {
    const [discRes, lessonsRes, materialsRes, progressRes, quizResultsRes, finalResultRes, finalQuizRes, lessonQuizzesRes, activityRes] = await Promise.all([
      supabase.from('disciplines').select('*').eq('id', id).single(),
      supabase.from('lessons').select('*').eq('discipline_id', id).order('order_index'),
      supabase.from('materials').select('*').eq('discipline_id', id).order('created_at'),
      supabase.from('lesson_progress').select('lesson_id').eq('user_id', user.id).eq('discipline_id', id),
      supabase.from('lesson_quiz_results').select('lesson_id, discipline_id, score, correct_answers, total_questions').eq('user_id', user.id).eq('discipline_id', id),
      supabase.from('quiz_results').select('discipline_id, score, correct_answers, total_questions').eq('user_id', user.id).eq('discipline_id', id).single(),
      supabase.from('quiz_questions').select('id').eq('discipline_id', id).is('lesson_id', null).limit(1),
      supabase.from('quiz_questions').select('lesson_id').eq('discipline_id', id).not('lesson_id', 'is', null),
      supabase.from('practical_activities').select('*').eq('discipline_id', id).maybeSingle(),
    ])

    setHasFinalQuiz((finalQuizRes.data || []).length > 0)
    setLessonsWithQuiz(new Set((lessonQuizzesRes.data || []).map(q => q.lesson_id).filter(Boolean)))

    if (discRes.data) setDiscipline(discRes.data)
    if (lessonsRes.data) setLessons(lessonsRes.data)
    if (materialsRes.data) setMaterials(materialsRes.data)

    // Atividade Prática + entrega do aluno
    const activity = activityRes.data || null
    setPracticalActivity(activity)
    if (activity) {
      const { data: subData } = await supabase
        .from('practical_submissions')
        .select('*')
        .eq('activity_id', activity.id)
        .eq('user_id', user.id)
        .maybeSingle()
      if (subData) {
        setPracticalSubmission(subData)
        setSubmissionMode(subData.submission_type || 'text')
        setSubmissionText(subData.content_text || '')
      }
    }

    const completedIds = new Set((progressRes.data || []).map(p => p.lesson_id))
    setCompletedLessons(completedIds)

    const quizResults = quizResultsRes.data || []
    setLessonQuizResultsData(quizResults)
    const finalResult = finalResultRes.data || null
    setFinalQuizResultData(finalResult)

    // Compute badges
    if (lessonsRes.data) {
      const badgeResult = computeDisciplineBadges({
        lessons: lessonsRes.data,
        completedLessonIds: completedIds,
        lessonQuizResults: quizResults,
        finalQuizResult: finalResult,
      })
      setDisciplineBadges(badgeResult.badges)
      setPerfectLessonIds(badgeResult.perfectLessonIds)
      setLessonBadges(badgeResult.lessonBadges)
    }

    setLoading(false)
  }

  const fetchRanking = async () => {
    setLoadingRanking(true)
    try {
      const { data, error } = await supabase.rpc('get_discipline_badge_ranking', { p_discipline_id: id })
      if (!error && data) {
        setRanking(data)
      }
    } catch (e) {
      console.error('Erro ao carregar ranking:', e)
    }
    setLoadingRanking(false)
  }

  const getMedalEmoji = (position) => {
    if (position === 0) return '🥇'
    if (position === 1) return '🥈'
    if (position === 2) return '🥉'
    return `${position + 1}º`
  }

  // Check if lesson is accessible (sequential order)
  // Perfis com acesso total (coordenação) ignoram a ordem sequencial.
  const isLessonAccessible = (index) => {
    if (fullAccess) return true
    if (index === 0) return true
    return completedLessons.has(lessons[index - 1].id)
  }

  // Open lesson quiz
  const startLessonQuiz = async (lessonId) => {
    if (lessonQuizQuestions[lessonId]) {
      setActiveLessonQuiz(lessonId)
      setLessonQuizAnswers({})
      setLessonQuizSubmitted(false)
      setLessonQuizScore(null)
      return
    }

    setLoadingQuiz(true)
    const { data } = await supabase
      .from('quiz_questions')
      .select('*')
      .eq('lesson_id', lessonId)
      .order('order_index')

    setLessonQuizQuestions(prev => ({ ...prev, [lessonId]: data || [] }))
    setActiveLessonQuiz(lessonId)
    setLessonQuizAnswers({})
    setLessonQuizSubmitted(false)
    setLessonQuizScore(null)
    setLoadingQuiz(false)
  }

  // Handle lesson quiz answer
  const handleLessonQuizAnswer = (questionId, optionIndex) => {
    if (lessonQuizSubmitted) return
    setLessonQuizAnswers(prev => ({ ...prev, [questionId]: optionIndex }))
  }

  // Submit lesson quiz
  const submitLessonQuiz = async (lessonId) => {
    const questions = lessonQuizQuestions[lessonId] || []
    if (Object.keys(lessonQuizAnswers).length < questions.length) {
      alert('Responda todas as questões antes de enviar.')
      return
    }

    let correct = 0
    questions.forEach(q => {
      if (lessonQuizAnswers[q.id] === q.correct_option) correct++
    })

    const total = questions.length
    const passed = correct >= Math.ceil(total * 0.66) // 2/3 corretas
    const scorePercent = Math.round((correct / total) * 100)

    setLessonQuizScore({ correct, total, passed, scorePercent })
    setLessonQuizSubmitted(true)

    // Save quiz result
    await supabase.from('lesson_quiz_results').upsert({
      user_id: user.id,
      lesson_id: lessonId,
      discipline_id: id,
      score: scorePercent,
      total_questions: total,
      correct_answers: correct,
      passed,
      completed_at: new Date().toISOString()
    }, { onConflict: 'user_id,lesson_id' })

    // If passed, mark lesson as completed
    if (passed) {
      await supabase.from('lesson_progress').upsert({
        user_id: user.id,
        lesson_id: lessonId,
        discipline_id: id,
        completed_at: new Date().toISOString()
      }, { onConflict: 'user_id,lesson_id' })

      setCompletedLessons(prev => new Set([...prev, lessonId]))
    }

    // Recompute badges after quiz
    const updatedQuizResults = [...lessonQuizResultsData.filter(r => r.lesson_id !== lessonId), {
      lesson_id: lessonId,
      discipline_id: id,
      score: scorePercent,
      correct_answers: correct,
      total_questions: total,
    }]
    setLessonQuizResultsData(updatedQuizResults)

    const updatedCompletedIds = passed
      ? new Set([...completedLessons, lessonId])
      : completedLessons

    const badgeResult = computeDisciplineBadges({
      lessons,
      completedLessonIds: updatedCompletedIds,
      lessonQuizResults: updatedQuizResults,
      finalQuizResult: finalQuizResultData,
    })

    // Check for new badges
    const oldBadgeIds = new Set(disciplineBadges.map(b => b.id))
    const newBadges = badgeResult.badges.filter(b => !oldBadgeIds.has(b.id))
    if (newBadges.length > 0) {
      setNewBadge(newBadges[0]) // Show first new badge
    }

    // Also check per-lesson badge (quiz perfect)
    if (scorePercent === 100) {
      const prevLessonBadges = lessonBadges.get(lessonId) || []
      if (!prevLessonBadges.some(b => b.id === 'lesson_quiz_perfect')) {
        setNewBadge({ id: 'lesson_quiz_perfect', name: 'Nota Máxima', description: 'Acertou 100% no quiz da aula', icon: '⭐', tier: 'gold' })
      }
    } else {
      // Badge de quiz respondido (se ainda não tinha)
      const prevLessonBadges = lessonBadges.get(lessonId) || []
      if (!prevLessonBadges.some(b => b.id === 'lesson_quiz_done')) {
        setNewBadge({ id: 'lesson_quiz_done', name: 'Quiz Respondido', description: 'Respondeu o quiz da aula', icon: '📝', tier: 'bronze' })
      }
    }

    setDisciplineBadges(badgeResult.badges)
    setPerfectLessonIds(badgeResult.perfectLessonIds)
    setLessonBadges(badgeResult.lessonBadges)
  }

  // Mark lesson complete manually (when no quiz questions exist)
  const markLessonComplete = async (lessonId) => {
    await supabase.from('lesson_progress').upsert({
      user_id: user.id,
      lesson_id: lessonId,
      discipline_id: id,
      completed_at: new Date().toISOString()
    }, { onConflict: 'user_id,lesson_id' })

    setCompletedLessons(prev => new Set([...prev, lessonId]))
  }

  // Reset lesson quiz to retry
  const retryLessonQuiz = () => {
    setLessonQuizAnswers({})
    setLessonQuizSubmitted(false)
    setLessonQuizScore(null)
  }

  // Start watch timer when video is opened
  const startWatchTimer = (lessonId) => {
    if (watchedLessons.has(lessonId) || watchReady.has(lessonId)) return
    // Show "Já assisti" button after 10 seconds
    const timer = setTimeout(() => {
      setWatchReady(prev => new Set([...prev, lessonId]))
    }, 10000)
    setWatchTimers(prev => ({ ...prev, [lessonId]: timer }))
  }

  // Clear watch timer
  const clearWatchTimer = (lessonId) => {
    if (watchTimers[lessonId]) {
      clearTimeout(watchTimers[lessonId])
      setWatchTimers(prev => {
        const next = { ...prev }
        delete next[lessonId]
        return next
      })
    }
  }

  // Mark video as watched and auto-open quiz
  const markVideoWatched = async (lessonId) => {
    setWatchedLessons(prev => new Set([...prev, lessonId]))
    // Auto-start the quiz
    startLessonQuiz(lessonId)
  }

  // ═══════════════════════════════════════
  // ATIVIDADE PRÁTICA — entrega do aluno
  // ═══════════════════════════════════════
  const DOCX_TYPES = [
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]

  const handleSubmissionFileSelect = (e) => {
    const file = e.target.files[0]
    if (!file) return

    const isDocx = DOCX_TYPES.includes(file.type) || /\.docx?$/i.test(file.name)
    if (!isDocx) {
      alert('Arquivo inválido. A entrega por arquivo deve ser em Word (.doc ou .docx).')
      e.target.value = ''
      return
    }
    if (file.size > 50 * 1024 * 1024) {
      alert('Arquivo muito grande. O limite é 50MB.')
      e.target.value = ''
      return
    }
    setSubmissionFile(file)
  }

  const uploadSubmissionFile = async (file) => {
    const fileExt = file.name.split('.').pop()
    const fileName = `${id}/${user.id}_${Date.now()}.${fileExt}`
    const { error } = await supabase.storage
      .from('practical-submissions')
      .upload(fileName, file, { cacheControl: '3600', upsert: true })
    if (error) throw error
    const { data: publicUrlData } = supabase.storage
      .from('practical-submissions')
      .getPublicUrl(fileName)
    return { url: publicUrlData.publicUrl, filePath: fileName }
  }

  const submitPracticalActivity = async () => {
    if (!practicalActivity) return

    if (submissionMode === 'text') {
      if (!submissionText.trim()) {
        return alert('Escreva sua resposta antes de enviar.')
      }
    } else {
      if (!submissionFile && !practicalSubmission?.file_path) {
        return alert('Selecione o arquivo .docx da sua atividade antes de enviar.')
      }
    }

    setSubmittingActivity(true)
    try {
      let submissionData = {
        activity_id: practicalActivity.id,
        discipline_id: id,
        user_id: user.id,
        submission_type: submissionMode,
        submitted_at: new Date().toISOString(),
        // ao reenviar, volta para "pendente" para o admin reavaliar
        status: 'pendente',
        grade: null,
        feedback: null,
        graded_at: null,
      }

      if (submissionMode === 'text') {
        submissionData.content_text = submissionText.trim()
        submissionData.file_path = null
        submissionData.file_url = null
        submissionData.file_name = null
      } else {
        if (submissionFile) {
          // remove arquivo anterior, se houver
          if (practicalSubmission?.file_path) {
            await supabase.storage.from('practical-submissions').remove([practicalSubmission.file_path])
          }
          const { url, filePath } = await uploadSubmissionFile(submissionFile)
          submissionData.file_path = filePath
          submissionData.file_url = url
          submissionData.file_name = submissionFile.name
        } else {
          // manteve o arquivo já enviado anteriormente
          submissionData.file_path = practicalSubmission.file_path
          submissionData.file_url = practicalSubmission.file_url
          submissionData.file_name = practicalSubmission.file_name
        }
        submissionData.content_text = null
      }

      const { data, error } = await supabase
        .from('practical_submissions')
        .upsert(submissionData, { onConflict: 'user_id,activity_id' })
        .select()
        .single()

      if (error) throw error

      setPracticalSubmission(data)
      setSubmissionFile(null)
      if (submissionFileRef.current) submissionFileRef.current.value = ''
      alert('Atividade entregue com sucesso!')
    } catch (err) {
      console.error('Erro ao enviar atividade:', err)
      alert('Erro ao enviar a atividade. Tente novamente.')
    }
    setSubmittingActivity(false)
  }

  if (loading) {
    return <div className="loading-screen"><div className="spinner"></div></div>
  }

  if (!discipline) {
    return <div className="error-state">Disciplina não encontrada.</div>
  }

  return (
    <div className="discipline-detail">
      <div className="detail-header">
        <Link to="/disciplinas" className="back-link">← Voltar às Disciplinas</Link>
        <div className="detail-title">
          <span className="detail-icon">{discipline.icon || '📖'}</span>
          <div>
            <h1>{discipline.name}</h1>
            <p>{discipline.description}</p>
          </div>
        </div>
      </div>

      {/* Barra de Progresso */}
      {lessons.length > 0 && (
        <div className="progress-section">
          <div className="progress-header">
            <span className="progress-label">Progresso das Aulas</span>
            <span className="progress-value">{completedCount}/{lessons.length} aulas concluídas ({progressPercent}%)</span>
          </div>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: `${progressPercent}%` }} />
          </div>
          {allLessonsCompleted && (
            <p className="progress-complete-msg">
              {hasFinalQuiz === false
                ? '✅ Todas as aulas foram concluídas! Disciplina finalizada com sucesso.'
                : allLessonQuizzesDone
                  ? '✅ Todas as aulas foram concluídas! O quiz final está liberado.'
                  : `⚠️ Faltam ${pendingLessonQuizCount} quiz(zes) de aula para liberar o quiz final.`}
            </p>
          )}
        </div>
      )}

      {/* Badges da Disciplina */}
      {disciplineBadges.length > 0 && (
        <div className="detail-badges-section">
          <div className="detail-badges-header">
            <h3>🏅 Conquistas</h3>
            <span className="detail-badges-count">{disciplineBadges.length}</span>
          </div>
          <BadgeGrid badges={disciplineBadges} />
        </div>
      )}

      <div className="tabs">
        <button
          className={`tab ${activeTab === 'aulas' ? 'active' : ''}`}
          onClick={() => setActiveTab('aulas')}
        >
          <FiPlay /> Aulas ({completedLessons.size}/{lessons.length})
        </button>
        <button
          className={`tab ${activeTab === 'materiais' ? 'active' : ''}`}
          onClick={() => setActiveTab('materiais')}
        >
          <FiFileText /> Materiais ({materials.length})
        </button>
        {practicalActivity && (
          <button
            className={`tab ${activeTab === 'atividade' ? 'active' : ''}`}
            onClick={() => setActiveTab('atividade')}
          >
            <FiClipboard /> Atividade Prática
            {practicalSubmission && <FiCheck className="tab-done-check" />}
          </button>
        )}

        {hasFinalQuiz === false && allLessonsCompleted ? (
          <span className="tab tab-quiz tab-quiz-unlocked" title="Disciplina concluída - sem quiz final">
            <FiCheckCircle /> Disciplina Concluída
          </span>
        ) : canAccessFinalQuiz ? (
          <Link to={`/disciplinas/${id}/quiz`} className="tab tab-quiz tab-quiz-unlocked">
            <FiCheckCircle /> Quiz Final
          </Link>
        ) : (
          <span
            className="tab tab-quiz tab-quiz-locked"
            title={
              !allLessonsCompleted
                ? 'Conclua todas as aulas para liberar o quiz final'
                : `Faltam ${pendingLessonQuizCount} quiz(zes) de aula para liberar o quiz final`
            }
          >
            <FiLock /> Quiz Final (bloqueado)
          </span>
        )}
      </div>

      {activeTab === 'aulas' && (
        <div className="lessons-list">
          {lessons.map((lesson, index) => {
            const isCompleted = completedLessons.has(lesson.id)
            const accessible = isLessonAccessible(index)
            const isActive = activeLesson?.id === lesson.id
            const isQuizOpen = activeLessonQuiz === lesson.id
            const quizQuestions = lessonQuizQuestions[lesson.id] || []

            return (
              <div key={lesson.id} className="lesson-wrapper">
                <div className={`lesson-card ${isCompleted ? 'completed' : ''} ${!accessible ? 'locked' : ''} ${isActive ? 'playing' : ''}`}>
                  <div className={`lesson-check ${isCompleted ? 'checked' : ''} ${!accessible ? 'lesson-check-locked' : ''}`}>
                    {isCompleted ? <FiCheck /> : !accessible ? <FiLock /> : <span className="lesson-number-text">{index + 1}</span>}
                  </div>
                  <div className="lesson-info">
                    <h3 className={isCompleted ? 'lesson-done' : ''}>
                      {lesson.title}
                      <InlineBadges badges={lessonBadges.get(lesson.id)?.filter(b => b.id === 'lesson_quiz_perfect') || []} />
                    </h3>
                    {lesson.description && <p>{lesson.description}</p>}
                    {!accessible && <span className="lesson-locked-msg">🔒 Complete a aula anterior primeiro</span>}
                    {isCompleted && <span className="lesson-completed-badge">✅ Concluída</span>}
                  </div>
                  {accessible && lesson.video_url && (
                    <button
                      className={`btn-watch ${isActive ? 'btn-watch-active' : ''}`}
                      onClick={() => {
                        if (isActive) {
                          setActiveLesson(null)
                          setActiveLessonQuiz(null)
                          setLessonQuizSubmitted(false)
                          clearWatchTimer(lesson.id)
                        } else {
                          setActiveLesson(lesson)
                          startWatchTimer(lesson.id)
                        }
                      }}
                    >
                      {isActive ? <><FiX /> Fechar</> : <><FiPlay /> Assistir</>}
                    </button>
                  )}
                </div>

                {/* Video Player */}
                {isActive && (
                  <div className="video-player-inline">
                    <div className="video-wrapper">
                      <iframe
                        src={getEmbedUrl(lesson.video_url)}
                        title={lesson.title}
                        frameBorder="0"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                        allowFullScreen
                      />
                    </div>

                    {/* Lesson quiz trigger / mark complete */}
                    {!isCompleted && !isQuizOpen && !watchedLessons.has(lesson.id) && (
                      <div className="lesson-actions">
                        {watchReady.has(lesson.id) ? (
                          <button
                            className="btn-lesson-watched"
                            onClick={() => markVideoWatched(lesson.id)}
                          >
                            <FiCheck /> Já assisti esta aula — Fazer Quiz
                          </button>
                        ) : (
                          <div className="lesson-watch-notice">
                            <div className="watch-notice-spinner"></div>
                            <span>Assista a aula para liberar o quiz...</span>
                          </div>
                        )}
                      </div>
                    )}
                    {!isCompleted && watchedLessons.has(lesson.id) && !isQuizOpen && (
                      <div className="lesson-actions">
                        <button
                          className="btn-lesson-quiz"
                          onClick={() => startLessonQuiz(lesson.id)}
                          disabled={loadingQuiz}
                        >
                          📝 {loadingQuiz ? 'Carregando...' : 'Fazer Quiz da Aula'}
                        </button>
                      </div>
                    )}
                  </div>
                )}

                {/* Lesson Quiz Inline */}
                {isQuizOpen && (
                  <div className="lesson-quiz-inline">
                    {quizQuestions.length === 0 ? (
                      <div className="lesson-quiz-empty">
                        <p>Nenhuma questão cadastrada para esta aula.</p>
                        <button className="btn-mark-complete" onClick={() => {
                          markLessonComplete(lesson.id)
                          setActiveLessonQuiz(null)
                        }}>
                          <FiCheck /> Marcar Aula como Concluída
                        </button>
                      </div>
                    ) : (
                      <>
                        <div className="lesson-quiz-header">
                          <h4>📝 Quiz da Aula: {lesson.title}</h4>
                          <p>Responda corretamente para concluir esta aula ({quizQuestions.length} questões)</p>
                        </div>

                        {lessonQuizSubmitted && lessonQuizScore && (
                          <div className={`lesson-quiz-result ${lessonQuizScore.passed ? 'passed' : 'failed'}`}>
                            <div className="lq-result-score">{lessonQuizScore.scorePercent}%</div>
                            <div className="lq-result-detail">
                              {lessonQuizScore.correct} de {lessonQuizScore.total} acertos
                            </div>
                            <div className="lq-result-text">
                              {lessonQuizScore.passed
                                ? '🎉 Aprovado! Aula concluída com sucesso.'
                                : '😕 Não atingiu a pontuação mínima. Revise o conteúdo e tente novamente.'}
                            </div>
                            {!lessonQuizScore.passed && (
                              <button className="btn-retry-lesson" onClick={retryLessonQuiz}>
                                🔄 Tentar Novamente
                              </button>
                            )}
                            {lessonQuizScore.passed && (
                              <button className="btn-next-lesson" onClick={() => {
                                setActiveLessonQuiz(null)
                                setActiveLesson(null)
                              }}>
                                Continuar →
                              </button>
                            )}
                          </div>
                        )}

                        <div className="lesson-quiz-questions">
                          {quizQuestions.map((q, qIndex) => (
                            <div key={q.id} className="lq-question-card">
                              <span className="lq-question-number">Questão {qIndex + 1}</span>
                              <p className="lq-question-text">{q.question}</p>
                              <div className="lq-options">
                                {q.options.map((option, oIndex) => {
                                  let cls = 'lq-option'
                                  if (lessonQuizAnswers[q.id] === oIndex) cls += ' selected'
                                  if (lessonQuizSubmitted) {
                                    if (oIndex === q.correct_option) cls += ' correct'
                                    else if (lessonQuizAnswers[q.id] === oIndex) cls += ' wrong'
                                  }
                                  return (
                                    <button
                                      key={oIndex}
                                      className={cls}
                                      onClick={() => handleLessonQuizAnswer(q.id, oIndex)}
                                      disabled={lessonQuizSubmitted}
                                    >
                                      <span className="lq-option-letter">{String.fromCharCode(65 + oIndex)}</span>
                                      <span>{option}</span>
                                    </button>
                                  )
                                })}
                              </div>

                              {lessonQuizSubmitted && q.correction_comment && (
                                <div className="correction-comment">
                                  <span className="correction-comment-icon">💡</span>
                                  <div className="correction-comment-text">{q.correction_comment}</div>
                                </div>
                              )}
                            </div>
                          ))}
                        </div>

                        {!lessonQuizSubmitted && (
                          <button
                            className="btn-submit-lesson-quiz"
                            onClick={() => submitLessonQuiz(lesson.id)}
                          >
                            Enviar Respostas ({Object.keys(lessonQuizAnswers).length}/{quizQuestions.length})
                          </button>
                        )}
                      </>
                    )}
                  </div>
                )}
              </div>
            )
          })}

          {lessons.length === 0 && (
            <div className="empty-state">
              <p>Nenhuma aula cadastrada para esta disciplina.</p>
            </div>
          )}
        </div>
      )}

      {activeTab === 'materiais' && (
        <div className="materials-list">
          {materials.map((mat) => (
            <a
              key={mat.id}
              href={mat.url}
              target="_blank"
              rel="noopener noreferrer"
              className="material-card"
              {...(mat.file_path ? { download: mat.title } : {})}
            >
              <div className="material-type">{getTypeIcon(mat.type)}</div>
              <div className="material-info">
                <h3>{mat.title}</h3>
                <div className="material-meta">
                  <span className="material-badge">{mat.type}</span>
                  {mat.file_path && (
                    <span className="material-download-hint">
                      <FiDownload /> Baixar arquivo
                    </span>
                  )}
                </div>
              </div>
            </a>
          ))}

          {materials.length === 0 && (
            <div className="empty-state">
              <p>Nenhum material disponível para esta disciplina.</p>
            </div>
          )}
        </div>
      )}

      {activeTab === 'atividade' && practicalActivity && (
        <div className="practical-activity">
          {/* Enunciado / conteúdo da atividade */}
          <div className="pa-card pa-content-card">
            <div className="pa-content-header">
              <span className="pa-icon"><FiClipboard /></span>
              <div>
                <h2>{practicalActivity.title || 'Atividade Prática'}</h2>
                <p className="pa-subtitle">Leia as instruções, realize a atividade e faça a sua entrega abaixo.</p>
              </div>
            </div>

            {practicalActivity.instructions && (
              <div className="pa-instructions">
                {practicalActivity.instructions.split('\n').map((line, i) => (
                  <p key={i}>{line}</p>
                ))}
              </div>
            )}

            {getActivityFiles(practicalActivity).map((file, i) => (
              <div className="pa-file-actions" key={file.url || i}>
                <span className="pa-file-name"><FiFile /> {file.name || `Arquivo ${i + 1}`}</span>
                <a
                  href={file.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="pa-btn pa-btn-view"
                >
                  <FiExternalLink /> Visualizar PDF
                </a>
                <a
                  href={file.url}
                  download={file.name || 'atividade-pratica.pdf'}
                  className="pa-btn pa-btn-download"
                >
                  <FiDownload /> Baixar PDF
                </a>
              </div>
            ))}
          </div>

          {/* Instruções de entrega */}
          <div className="pa-card pa-howto-card">
            <h3>📤 Como entregar a sua atividade</h3>
            <p>Você pode entregar a atividade de uma das duas formas abaixo. Escolha a que preferir:</p>
            <div className="pa-howto-options">
              <div className="pa-howto-option">
                <span className="pa-howto-num"><FiEdit3 /></span>
                <div>
                  <strong>Escrever na plataforma</strong>
                  <p>Digite a sua resposta diretamente no campo de texto. Ideal para respostas mais curtas ou objetivas.</p>
                </div>
              </div>
              <div className="pa-howto-option">
                <span className="pa-howto-num"><FiUpload /></span>
                <div>
                  <strong>Enviar um arquivo</strong>
                  <p>Faça o upload do seu trabalho. <strong>O arquivo deve estar em formato Word (.docx)</strong> — outros formatos não serão aceitos.</p>
                </div>
              </div>
            </div>
          </div>

          {/* Devolutiva do admin (se avaliada) */}
          {practicalSubmission?.status === 'avaliada' && (
            <div className="pa-card pa-feedback-card">
              <div className="pa-feedback-header">
                <FiCheckCircle /> Atividade avaliada
                {practicalSubmission.grade && (
                  <span className="pa-grade">Nota: {practicalSubmission.grade}</span>
                )}
              </div>
              {practicalSubmission.feedback && (
                <div className="pa-feedback-text">
                  <strong>Devolutiva do instrutor:</strong>
                  <p>{practicalSubmission.feedback}</p>
                </div>
              )}
            </div>
          )}

          {/* Área de entrega */}
          <div className="pa-card pa-submit-card">
            <div className="pa-submit-header">
              <h3>✍️ Sua Entrega</h3>
              {practicalSubmission && (
                <span className={`pa-status pa-status-${practicalSubmission.status}`}>
                  {practicalSubmission.status === 'avaliada' ? 'Avaliada' : 'Entregue — aguardando avaliação'}
                </span>
              )}
            </div>

            {practicalSubmission && (
              <p className="pa-submitted-note">
                Você já entregou esta atividade em{' '}
                {new Date(practicalSubmission.submitted_at).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}.
                Você pode reenviar a qualquer momento — a entrega anterior será substituída.
              </p>
            )}

            {/* Seletor de modo de entrega */}
            <div className="pa-mode-toggle">
              <button
                className={`pa-mode-btn ${submissionMode === 'text' ? 'active' : ''}`}
                onClick={() => setSubmissionMode('text')}
              >
                <FiEdit3 /> Escrever resposta
              </button>
              <button
                className={`pa-mode-btn ${submissionMode === 'file' ? 'active' : ''}`}
                onClick={() => setSubmissionMode('file')}
              >
                <FiUpload /> Enviar arquivo (.docx)
              </button>
            </div>

            {submissionMode === 'text' ? (
              <textarea
                className="pa-textarea"
                value={submissionText}
                onChange={e => setSubmissionText(e.target.value)}
                placeholder="Escreva aqui a sua resposta para a atividade..."
                rows={10}
              />
            ) : (
              <div className="pa-file-upload">
                <input
                  ref={submissionFileRef}
                  type="file"
                  accept=".doc,.docx,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                  onChange={handleSubmissionFileSelect}
                  className="pa-file-input-hidden"
                  id="pa-submission-file"
                />
                <label htmlFor="pa-submission-file" className="pa-file-label">
                  <FiUpload />
                  <span>
                    {submissionFile
                      ? submissionFile.name
                      : 'Clique para selecionar o seu arquivo Word (.docx)'}
                  </span>
                </label>

                {submissionFile && (
                  <div className="pa-file-selected">
                    <FiFile />
                    <span>{submissionFile.name}</span>
                    <span className="pa-file-size">({(submissionFile.size / (1024 * 1024)).toFixed(2)} MB)</span>
                    <button
                      type="button"
                      className="pa-file-remove"
                      onClick={() => {
                        setSubmissionFile(null)
                        if (submissionFileRef.current) submissionFileRef.current.value = ''
                      }}
                    >
                      <FiTrash2 />
                    </button>
                  </div>
                )}

                {!submissionFile && practicalSubmission?.file_path && (
                  <div className="pa-file-current">
                    <FiFile /> Arquivo enviado:{' '}
                    <a href={practicalSubmission.file_url} target="_blank" rel="noopener noreferrer" download={practicalSubmission.file_name}>
                      {practicalSubmission.file_name || 'documento.docx'}
                    </a>
                    <small>Selecione um novo arquivo para substituir, ou clique em enviar para manter o atual.</small>
                  </div>
                )}

                <p className="pa-file-hint">Apenas arquivos Word (.docx). Tamanho máximo: 50MB.</p>
              </div>
            )}

            <button
              className="pa-submit-btn"
              onClick={submitPracticalActivity}
              disabled={submittingActivity}
            >
              <FiSend /> {submittingActivity ? 'Enviando...' : practicalSubmission ? 'Reenviar Atividade' : 'Entregar Atividade'}
            </button>
          </div>
        </div>
      )}

      {/* Ranking da Disciplina */}
      <div className="discipline-ranking-section">
        <div className="discipline-ranking-header">
          <h3>🏅 Ranking da Disciplina</h3>
          <p>Os alunos com mais badges nesta disciplina</p>
        </div>

        {loadingRanking ? (
          <div className="discipline-ranking-loading">
            <div className="spinner"></div>
          </div>
        ) : ranking.length === 0 ? (
          <div className="discipline-ranking-empty">
            <p>Nenhum aluno completou atividades nesta disciplina ainda.</p>
          </div>
        ) : (
          <div className="discipline-ranking-table-wrapper">
            <table className="discipline-ranking-table">
              <thead>
                <tr>
                  <th className="dr-col-pos">#</th>
                  <th className="dr-col-name">Aluno</th>
                  <th className="dr-col-badges">Badges</th>
                </tr>
              </thead>
              <tbody>
                {ranking.map((entry, index) => {
                  const isCurrentUser = entry.user_id === user.id
                  return (
                    <tr
                      key={entry.user_id}
                      className={`dr-row ${isCurrentUser ? 'dr-row-current' : ''} ${index < 3 ? 'dr-row-top' : ''}`}
                    >
                      <td className="dr-col-pos">
                        <span className={`dr-medal ${index < 3 ? `dr-medal-${index + 1}` : ''}`}>
                          {getMedalEmoji(index)}
                        </span>
                      </td>
                      <td className="dr-col-name">
                        <span className="dr-name">{entry.user_name}</span>
                        {isCurrentUser && <span className="dr-you-tag">Você</span>}
                      </td>
                      <td className="dr-col-badges">
                        <span className="dr-badge-count">🏆 {entry.badge_count}</span>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Badge Unlocked Popup */}
      {newBadge && <BadgeUnlocked badge={newBadge} onClose={() => setNewBadge(null)} />}
    </div>
  )
}

function getTypeIcon(type) {
  switch (type?.toLowerCase()) {
    case 'livro': return '📕'
    case 'artigo': return '📄'
    case 'pdf': return '📑'
    case 'word': return '📘'
    case 'link': return '🔗'
    default: return '📎'
  }
}
